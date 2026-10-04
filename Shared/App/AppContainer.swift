import Foundation
import Observation
import SwiftData
import SwiftUI
import os

@Observable
@MainActor
final class AppContainer {
    static let shared = AppContainer()
    static let importDidFinishNotification = Notification.Name("FinanceCategorizerImportDidFinish")

    let modelContainer: ModelContainer
    let persistenceRecoveryIssue: PersistenceRecoveryIssue?

    let transactionRepository: TransactionRepository
    let categoryRepository: CategoryRepository
    let merchantRepository: MerchantRepository
    let ruleRepository: RuleRepository
    let importBatchRepository: ImportBatchRepository
    let correctionRepository: CorrectionRepository
    let insightRepository: InsightRepository
    let budgetRepository: BudgetRepository
    let accountRepository: AccountRepository
    let savingsGoalRepository: SavingsGoalRepository

    let normalizer: TransactionNormalizer
    let importOrchestrator: ImportOrchestrator
    let fileImportService: FileImportService
    let categorizationOrchestrator: CategorizationOrchestrator
    let recategorizationService: RecategorizationService
    let correctionLearningService: CorrectionLearningService
    let localModelManager: LocalModelManager
    let aiAvailabilityService: AIAvailabilityService
    let aiSuggestionService: AISuggestionService
    let foundationResolver: FoundationModelsResolver?
    let aiAnalysisSummaryService: AIAnalysisSummaryService
    let aiDashboardCopilotService: AIDashboardCopilotService
    let dashboardInsightService: DashboardInsightService
    let financialAnalysisService: FinancialAnalysisService
    let insightEngine: InsightEngine
    let duplicateAuditService: DuplicateAuditService
    let financialPlanningService: FinancialPlanningService
    let savingsStrategyStore: SavingsStrategyStore
    let savingsStrategyService: SavingsStrategyService

    init(inMemory: Bool = false) {
        let persistenceSetup = ModelContainerFactory.make(inMemory: inMemory)
        modelContainer = persistenceSetup.container
        persistenceRecoveryIssue = persistenceSetup.recoveryIssue

        transactionRepository = TransactionRepository(modelContainer: modelContainer)
        categoryRepository = CategoryRepository(modelContainer: modelContainer)
        merchantRepository = MerchantRepository(modelContainer: modelContainer)
        ruleRepository = RuleRepository(modelContainer: modelContainer)
        importBatchRepository = ImportBatchRepository(modelContainer: modelContainer)
        correctionRepository = CorrectionRepository(modelContainer: modelContainer)
        insightRepository = InsightRepository(modelContainer: modelContainer)
        budgetRepository = BudgetRepository(modelContainer: modelContainer)
        accountRepository = AccountRepository(modelContainer: modelContainer)
        savingsGoalRepository = SavingsGoalRepository(modelContainer: modelContainer)

        let fileImportService = FileImportService()
        let csvParsingService = CSVParsingService()
        let xlsxParsingService = XLSXParsingService()
        let pdfParsingService = PDFParsingService()
        let validationService = ImportValidationService()
        let normalizer = TransactionNormalizer()
        let aiAvailabilityService = AIAvailabilityService()
        let dashboardInsightService = DashboardInsightService()
        let financialAnalysisService = FinancialAnalysisService()
        let localModelManager = LocalModelManager(transactionRepository: transactionRepository)
        let insightEngine = InsightEngine(
            transactionRepository: transactionRepository,
            categoryRepository: categoryRepository,
            insightRepository: insightRepository
        )

        let ruleEngine = RuleEngine(ruleRepository: ruleRepository)
        let merchantMemory = MerchantMemoryEngine(
            transactionRepository: transactionRepository
        )
        let classifier = StatisticalClassifier(
            categoryRepository: categoryRepository,
            localModelManager: localModelManager
        )
        let foundationResolver = FoundationModelsResolver(
            categoryRepository: categoryRepository,
            transactionRepository: transactionRepository
        )
        let categorizationOrchestrator = CategorizationOrchestrator(
            categoryRepository: categoryRepository,
            ruleEngine: ruleEngine,
            merchantMemory: merchantMemory,
            classifier: classifier,
            foundationResolver: foundationResolver,
            confidenceScorer: ConfidenceScorer()
        )
        let merchantLearningStore = MerchantLearningStore(merchantRepository: merchantRepository)
        let correctionLearningService = CorrectionLearningService(
            correctionRepository: correctionRepository,
            categoryRepository: categoryRepository,
            merchantLearningStore: merchantLearningStore,
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            ruleSuggestionEngine: RuleSuggestionEngine(),
            localModelManager: localModelManager
        )
        let aiSuggestionService = AISuggestionService(
            availabilityService: aiAvailabilityService,
            promptBuilder: AIPromptBuilder(),
            categoryRepository: categoryRepository,
            transactionRepository: transactionRepository
        )

        try? categoryRepository.ensureBaseCategories()
        Task(priority: .utility) { [localModelManager] in
            do {
                try localModelManager.rebuildModelIfNeeded()
            } catch {
                Logger(subsystem: "com.mariofernandez.FinanceCategorizer", category: "MLModel").error("Failed to rebuild local ML model: \(error.localizedDescription)")
            }
        }

        self.normalizer = normalizer
        self.fileImportService = fileImportService
        self.categorizationOrchestrator = categorizationOrchestrator
        self.recategorizationService = RecategorizationService(
            transactionRepository: transactionRepository,
            categorizationOrchestrator: categorizationOrchestrator
        )
        self.localModelManager = localModelManager
        self.foundationResolver = foundationResolver
        self.correctionLearningService = correctionLearningService
        self.aiAvailabilityService = aiAvailabilityService
        self.aiSuggestionService = aiSuggestionService
        self.aiAnalysisSummaryService = AIAnalysisSummaryService(availabilityService: aiAvailabilityService)
        self.aiDashboardCopilotService = AIDashboardCopilotService(availabilityService: aiAvailabilityService)
        self.dashboardInsightService = dashboardInsightService
        self.financialAnalysisService = financialAnalysisService
        self.insightEngine = insightEngine
        self.duplicateAuditService = DuplicateAuditService()
        self.financialPlanningService = FinancialPlanningService()
        self.savingsStrategyStore = SavingsStrategyStore()
        self.savingsStrategyService = SavingsStrategyService()
        self.importOrchestrator = ImportOrchestrator(
            transactionRepository: transactionRepository,
            categoryRepository: categoryRepository,
            importBatchRepository: importBatchRepository,
            categorizer: categorizationOrchestrator,
            normalizer: normalizer,
            fileImportService: fileImportService,
            csvParsingService: csvParsingService,
            xlsxParsingService: xlsxParsingService,
            pdfParsingService: pdfParsingService,
            validationService: validationService,
            insightEngine: insightEngine,
            localModelManager: localModelManager
        )
    }
}
private struct AppContainerKey: EnvironmentKey {
    static let defaultValue: AppContainer = MainActor.assumeIsolated {
        AppContainer.shared
    }
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}
