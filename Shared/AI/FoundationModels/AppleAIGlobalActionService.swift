import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

protocol AIAvailabilityChecking {
    func isAvailable() -> Bool
}

extension AIAvailabilityService: AIAvailabilityChecking {}

enum AppleAISurface: String, CaseIterable, Identifiable {
    case dashboard
    case imports
    case transactions
    case analysis
    case review
    case categories
    case budgets
    case settings

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .imports: return "Imports"
        case .transactions: return "Transactions"
        case .analysis: return "Analysis"
        case .review: return "Review Queue"
        case .categories: return "Categories"
        case .budgets: return "Budgets"
        case .settings: return "Settings"
        }
    }

    func title(language: AppLanguage) -> String {
        language.localized(titleKey)
    }
}

enum AppleAIIntent: String, CaseIterable, Identifiable {
    case monthlyBriefing
    case optimizeSpending
    case importHealth
    case importTips
    case uncategorizedScan
    case recurringMerchants
    case analysisPatterns
    case savingsIdeas
    case reviewPriorities
    case batchResolution
    case categoryCleanup
    case ruleCandidates
    case budgetPressure
    case categoriesOverPlan
    case aiDiagnostics
    case learningReadiness

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .monthlyBriefing: return "appleAI.intent.monthlyBriefing.title"
        case .optimizeSpending: return "appleAI.intent.optimizeSpending.title"
        case .importHealth: return "appleAI.intent.importHealth.title"
        case .importTips: return "appleAI.intent.importTips.title"
        case .uncategorizedScan: return "appleAI.intent.uncategorizedScan.title"
        case .recurringMerchants: return "appleAI.intent.recurringMerchants.title"
        case .analysisPatterns: return "appleAI.intent.analysisPatterns.title"
        case .savingsIdeas: return "appleAI.intent.savingsIdeas.title"
        case .reviewPriorities: return "appleAI.intent.reviewPriorities.title"
        case .batchResolution: return "appleAI.intent.batchResolution.title"
        case .categoryCleanup: return "appleAI.intent.categoryCleanup.title"
        case .ruleCandidates: return "appleAI.intent.ruleCandidates.title"
        case .budgetPressure: return "appleAI.intent.budgetPressure.title"
        case .categoriesOverPlan: return "appleAI.intent.categoriesOverPlan.title"
        case .aiDiagnostics: return "appleAI.intent.aiDiagnostics.title"
        case .learningReadiness: return "appleAI.intent.learningReadiness.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .monthlyBriefing:
            return "appleAI.intent.monthlyBriefing.subtitle"
        case .optimizeSpending:
            return "appleAI.intent.optimizeSpending.subtitle"
        case .importHealth:
            return "appleAI.intent.importHealth.subtitle"
        case .importTips:
            return "appleAI.intent.importTips.subtitle"
        case .uncategorizedScan:
            return "appleAI.intent.uncategorizedScan.subtitle"
        case .recurringMerchants:
            return "appleAI.intent.recurringMerchants.subtitle"
        case .analysisPatterns:
            return "appleAI.intent.analysisPatterns.subtitle"
        case .savingsIdeas:
            return "appleAI.intent.savingsIdeas.subtitle"
        case .reviewPriorities:
            return "appleAI.intent.reviewPriorities.subtitle"
        case .batchResolution:
            return "appleAI.intent.batchResolution.subtitle"
        case .categoryCleanup:
            return "appleAI.intent.categoryCleanup.subtitle"
        case .ruleCandidates:
            return "appleAI.intent.ruleCandidates.subtitle"
        case .budgetPressure:
            return "appleAI.intent.budgetPressure.subtitle"
        case .categoriesOverPlan:
            return "appleAI.intent.categoriesOverPlan.subtitle"
        case .aiDiagnostics:
            return "appleAI.intent.aiDiagnostics.subtitle"
        case .learningReadiness:
            return "appleAI.intent.learningReadiness.subtitle"
        }
    }

    func title(language: AppLanguage) -> String {
        language.localized(titleKey)
    }

    func subtitle(language: AppLanguage) -> String {
        language.localized(subtitleKey)
    }

    var systemImage: String {
        switch self {
        case .monthlyBriefing: return "sparkles.rectangle.stack"
        case .optimizeSpending: return "leaf"
        case .importHealth: return "square.and.arrow.down.on.square"
        case .importTips: return "lightbulb"
        case .uncategorizedScan: return "questionmark.folder"
        case .recurringMerchants: return "repeat"
        case .analysisPatterns: return "chart.xyaxis.line"
        case .savingsIdeas: return "eurosign.circle"
        case .reviewPriorities: return "checklist"
        case .batchResolution: return "square.stack.3d.down.forward"
        case .categoryCleanup: return "tag"
        case .ruleCandidates: return "wand.and.rays"
        case .budgetPressure: return "gauge.with.dots.needle.67percent"
        case .categoriesOverPlan: return "target"
        case .aiDiagnostics: return "stethoscope"
        case .learningReadiness: return "brain"
        }
    }

    static func actions(for surface: AppleAISurface) -> [AppleAIIntent] {
        switch surface {
        case .dashboard:
            return [.monthlyBriefing, .optimizeSpending]
        case .imports:
            return [.importHealth, .importTips]
        case .transactions:
            return [.uncategorizedScan, .recurringMerchants]
        case .analysis:
            return [.analysisPatterns, .savingsIdeas]
        case .review:
            return [.reviewPriorities, .batchResolution]
        case .categories:
            return [.categoryCleanup, .ruleCandidates]
        case .budgets:
            return [.budgetPressure, .categoriesOverPlan]
        case .settings:
            return [.aiDiagnostics, .learningReadiness]
        }
    }
}

struct AppleAIActionResult {
    let title: String
    let summary: String
    let bullets: [String]
}

struct AppleAIContext {
    var selectedTransactionID: UUID?
    var selectedImportBatchID: UUID?

    static let empty = AppleAIContext()
}

private struct BudgetPressureItem {
    let categoryName: String
    let spent: Decimal
    let limit: Decimal
    let progress: Double
}

private struct AppleAIFacts {
    let transactionCount: Int
    let categorizedCount: Int
    let pendingReviewCount: Int
    let dashboardSnapshot: DashboardSnapshot?
    let analysisSnapshot: FinancialAnalysisSnapshot?
    let topExpenseCategories: [String]
    let topExpenseMerchants: [String]
    let uncategorizedExamples: [String]
    let recurringCandidates: [String]
    let repeatableMerchantsWithoutCategory: [String]
    let recentImports: [ImportBatch]
    let emptyCategories: [String]
    let duplicatedCategoryNames: [String]
    let budgets: [Budget]
    let overBudgetItems: [BudgetPressureItem]
    let nearLimitItems: [BudgetPressureItem]
    let foundationModelsAvailable: Bool
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
@Generable
struct AppleAIStructuredResponse {
    var title: String
    var summary: String
    var bullets: [String]
}
#endif

@MainActor
struct AppleAIGlobalActionService {
    private let availabilityService: AIAvailabilityChecking

    init(availabilityService: AIAvailabilityChecking = AIAvailabilityService()) {
        self.availabilityService = availabilityService
    }

    func run(
        _ intent: AppleAIIntent,
        surface: AppleAISurface,
        using container: AppContainer,
        language: AppLanguage = .currentSelection,
        context: AppleAIContext = .empty
    ) async -> AppleAIActionResult {
        let facts = loadFacts(using: container, context: context, language: language)

        #if canImport(FoundationModels)
        if availabilityService.isAvailable() {
            if #available(macOS 26.0, iOS 26.0, *) {
                do {
                    let session = LanguageModelSession(
                        instructions: """
                        Eres un copiloto financiero local para una app de finanzas personales.
                        Usa solo los hechos recibidos.
                        Sé concreto, prudente y accionable.
                        Devuelve un título corto, un resumen útil y entre 3 y 5 bullets.
                        No inventes números ni categorías.
                        """
                    )

                    let response = try await session.respond(
                        to: prompt(for: intent, surface: surface, facts: facts, language: language),
                        generating: AppleAIStructuredResponse.self
                    )

                    let content = response.content
                    let bullets = Array(
                        content.bullets
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                            .prefix(5)
                    )

                    guard !content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !content.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !bullets.isEmpty else {
                        return deterministicResult(for: intent, facts: facts, language: language)
                    }

                    return AppleAIActionResult(
                        title: content.title,
                        summary: content.summary,
                        bullets: bullets
                    )
                } catch {
                    return deterministicResult(for: intent, facts: facts, language: language)
                }
            }
        }
        #endif

        return deterministicResult(for: intent, facts: facts, language: language)
    }

    private func loadFacts(using container: AppContainer, context: AppleAIContext, language: AppLanguage) -> AppleAIFacts {
        let transactions = (try? container.transactionRepository.fetchAll()) ?? []
        let categories = (try? container.categoryRepository.fetchAll()) ?? []
        let recentImports = (try? container.importBatchRepository.fetchRecentBatches(limit: 6)) ?? []
        let pendingReview = (try? container.transactionRepository.fetchPendingReview()) ?? []

        let dashboardSnapshot = container.dashboardInsightService.buildSnapshot(
            transactions: transactions,
            categories: categories,
            recentImports: recentImports,
            locale: language.locale
        )
        let analysisSnapshot = container.financialAnalysisService.analyze(
            transactions: transactions,
            categories: categories,
            pendingReviewCount: pendingReview.count,
            range: .sixMonths
        )

        let categorizedCount = transactions.filter { $0.categoryID != nil }.count
        let categoryNameByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

        let expenseByCategory = Dictionary(grouping: transactions.filter { $0.resolvedKind == .expense && $0.categoryID != nil }) {
            $0.categoryID!
        }
        .map { key, values in
            (
                name: categoryNameByID[key] ?? "Sin categorizar",
                total: values.reduce(Decimal.zero) { $0 + absolute($1.amount) }
            )
        }
        .sorted { $0.total > $1.total }
        .prefix(5)
        .map { "\($0.name): \(formattedCurrency($0.total, language: language))" }

        let expenseByMerchant = Dictionary(grouping: transactions.filter { $0.resolvedKind == .expense }) {
            normalizedMerchantName(from: $0)
        }
        .map { merchant, values in
            (
                merchant: merchant,
                total: values.reduce(Decimal.zero) { $0 + absolute($1.amount) },
                count: values.count
            )
        }
        .filter { !$0.merchant.isEmpty }
        .sorted { lhs, rhs in
            if lhs.total == rhs.total {
                return lhs.count > rhs.count
            }
            return lhs.total > rhs.total
        }
        .prefix(5)
        .map { "\($0.merchant): \(formattedCurrency($0.total, language: language)) · \(language.formatInteger($0.count)) \(language.localized("appleAI.movements.short"))" }

        let uncategorizedExamples = pendingReview.prefix(5).map { transaction in
            let merchant = normalizedMerchantName(from: transaction)
            let label = merchant.isEmpty ? transaction.cleanedDescription : merchant
            return "\(label) · \(formattedCurrency(absolute(transaction.amount), language: language))"
        }

        let recurringCandidates = Dictionary(grouping: transactions.filter { $0.resolvedKind == .expense }) {
            normalizedMerchantName(from: $0)
        }
        .map { merchant, values in
            (
                merchant: merchant,
                count: values.count,
                average: average(values.map { absolute($0.amount) })
            )
        }
        .filter { !$0.merchant.isEmpty && $0.count >= 2 }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.average > rhs.average
            }
            return lhs.count > rhs.count
        }
        .prefix(5)
        .map { "\($0.merchant): \(language.formatInteger($0.count)) \(language.localized("appleAI.charges.short")), \(language.localized("appleAI.average.short")) \(formattedCurrency($0.average, language: language))" }

        let repeatableMerchantsWithoutCategory = Dictionary(grouping: pendingReview) {
            normalizedMerchantName(from: $0)
        }
        .map { merchant, values in
            (merchant: merchant, count: values.count)
        }
        .filter { !$0.merchant.isEmpty && $0.count >= 2 }
        .sorted { $0.count > $1.count }
        .prefix(5)
        .map { "\($0.merchant): \(language.formatInteger($0.count)) \(language.localized("Pending"))" }

        let usedCategoryIDs = Set(transactions.compactMap(\.categoryID))
        let emptyCategories = categories
            .filter { !usedCategoryIDs.contains($0.id) }
            .map(\.name)
            .sorted()

        let duplicatedCategoryNames = Dictionary(grouping: categories) {
            $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        .values
        .filter { $0.count > 1 }
        .map { items in items.map(\.name).joined(separator: " / ") }
        .sorted()

        let currentMonthBudgets = (try? container.budgetRepository.fetch(forMonthYear: currentMonthYear())) ?? []
        let budgetPressureItems = currentMonthBudgets.compactMap { budget in
            let spent = transactions
                .filter { $0.categoryID == budget.categoryID }
                .filter { $0.resolvedKind == .expense }
                .filter { isCurrentMonth($0.accountingDate, referenceDate: Date()) }
                .reduce(Decimal.zero) { $0 + absolute($1.amount) }
            let progress = budget.limitAmount == .zero ? 0 : decimalToDouble(spent / budget.limitAmount)
            let categoryName = categoryNameByID[budget.categoryID] ?? language.localized("Unknown Category")
            return BudgetPressureItem(
                categoryName: categoryName,
                spent: spent,
                limit: budget.limitAmount,
                progress: progress
            )
        }
        .sorted { $0.progress > $1.progress }
        _ = context.selectedTransactionID
        _ = context.selectedImportBatchID

        return AppleAIFacts(
            transactionCount: transactions.count,
            categorizedCount: categorizedCount,
            pendingReviewCount: pendingReview.count,
            dashboardSnapshot: dashboardSnapshot,
            analysisSnapshot: analysisSnapshot,
            topExpenseCategories: expenseByCategory,
            topExpenseMerchants: expenseByMerchant,
            uncategorizedExamples: uncategorizedExamples,
            recurringCandidates: recurringCandidates,
            repeatableMerchantsWithoutCategory: repeatableMerchantsWithoutCategory,
            recentImports: recentImports,
            emptyCategories: emptyCategories,
            duplicatedCategoryNames: duplicatedCategoryNames,
            budgets: currentMonthBudgets,
            overBudgetItems: budgetPressureItems.filter { $0.progress >= 1.0 },
            nearLimitItems: budgetPressureItems.filter { $0.progress >= 0.8 && $0.progress < 1.0 },
            foundationModelsAvailable: availabilityService.isAvailable()
        )
    }

    private func prompt(for intent: AppleAIIntent, surface: AppleAISurface, facts: AppleAIFacts, language: AppLanguage) -> String {
        let dashboard = facts.dashboardSnapshot
        let analysis = facts.analysisSnapshot

        return """
        \(language.localized("appleAI.currentScreen", surface.title(language: language)))
        \(language.localized("appleAI.runAction")): \(intent.title(language: language))

        \(language.localized("appleAI.whatItWillDo")):
        - \(language.localized("appleAI.movements")): \(facts.transactionCount)
        - \(language.localized("appleAI.autoCategorized")): \(facts.categorizedCount)
        - \(language.localized("Pending")): \(facts.pendingReviewCount)
        - Foundation Models: \(facts.foundationModelsAvailable ? (language == .spanish ? "sí" : "yes") : "no")

        Dashboard:
        - \(language.localized("Dashboard")): \(dashboard?.monthTitle ?? language.localized("appleAI.noData"))
        - \(language.localized("Income")): \(dashboard.map { formattedCurrency($0.totalIncome, language: language) } ?? language.localized("appleAI.noData"))
        - \(language.localized("Expenses")): \(dashboard.map { formattedCurrency($0.totalExpenses, language: language) } ?? language.localized("appleAI.noData"))
        - \(language.localized("Delta")): \(dashboard.map { formattedCurrency($0.netBalance, language: language) } ?? language.localized("appleAI.noData"))
        - %: \(dashboard.map { formattedPercent($0.categorizedPercentage, language: language) } ?? language.localized("appleAI.noData"))
        - \(language.localized("Category")): \(dashboard?.dominantCategoryName ?? language.localized("appleAI.noData"))

        Analysis:
        - \(language.localized("Income")): \(analysis.map { formattedCurrency($0.totalIncome, language: language) } ?? language.localized("appleAI.noData"))
        - \(language.localized("Expenses")): \(analysis.map { formattedCurrency($0.totalExpenses, language: language) } ?? language.localized("appleAI.noData"))
        - \(language.localized("Delta")): \(analysis.map { formattedCurrency($0.netBalance, language: language) } ?? language.localized("appleAI.noData"))
        - Forecast 3m: \(analysis.map { formattedCurrency($0.forecast.projectedDelta3Months, language: language) } ?? language.localized("appleAI.noData"))
        - Forecast 6m: \(analysis.map { formattedCurrency($0.forecast.projectedDelta6Months, language: language) } ?? language.localized("appleAI.noData"))

        Lists:
        - \(language.localized("Top Categories")): \(joinedList(facts.topExpenseCategories, language: language))
        - Top Merchants: \(joinedList(facts.topExpenseMerchants, language: language))
        - Pending: \(joinedList(facts.uncategorizedExamples, language: language))
        - Recurring: \(joinedList(facts.recurringCandidates, language: language))
        - Repeatable: \(joinedList(facts.repeatableMerchantsWithoutCategory, language: language))
        - Imports: \(joinedList(facts.recentImports.map { "\($0.fileName) · \(language.formatInteger($0.importedRowCount)) \(language.localized("appleAI.rows.short")) · \(formattedDate($0.importedAt, language: language))" }, language: language))
        - Empty: \(joinedList(facts.emptyCategories, language: language))
        - Duplicates: \(joinedList(facts.duplicatedCategoryNames, language: language))
        - Over Budget: \(joinedList(facts.overBudgetItems.map { budgetLine($0, language: language) }, language: language))
        - Near Limit: \(joinedList(facts.nearLimitItems.map { budgetLine($0, language: language) }, language: language))

        Response requirements:
        - short title
        - 2-4 sentences summary
        - 3-5 actionable bullets
        - language: \(language.title)
        """
    }

    private func deterministicResult(for intent: AppleAIIntent, facts: AppleAIFacts, language: AppLanguage) -> AppleAIActionResult {
        let prefix = "appleAI.deterministic.\(intent.rawValue)"
        
        let title = language.localized("\(prefix).title")
        
        let summary: String
        switch intent {
        case .monthlyBriefing:
            if let snapshot = facts.dashboardSnapshot {
                summary = language.localized("\(prefix).summary", 
                                          snapshot.monthTitle, 
                                          formattedCurrency(snapshot.totalIncome, language: language), 
                                          formattedCurrency(snapshot.totalExpenses, language: language), 
                                          formattedCurrency(snapshot.netBalance, language: language), 
                                          Int64(facts.pendingReviewCount))
            } else {
                summary = language.localized("\(prefix).noHistory")
            }
        case .importHealth:
            if !facts.recentImports.isEmpty {
                let importedRows = facts.recentImports.reduce(0) { $0 + $1.importedRowCount }
                let pendingRows = facts.recentImports.reduce(0) { $0 + $1.pendingReviewCount }
                summary = language.localized("\(prefix).summary", Int64(facts.recentImports.count), Int64(importedRows), Int64(pendingRows))
            } else {
                summary = language.localized("\(prefix).noHistory")
            }
        case .uncategorizedScan:
            summary = language.localized("\(prefix).summary", Int64(facts.pendingReviewCount))
        case .analysisPatterns:
            if let snapshot = facts.analysisSnapshot {
                summary = language.localized("\(prefix).summary", 
                                          snapshot.range.title, 
                                          formattedCurrency(snapshot.netBalance, language: language), 
                                          formattedCurrency(snapshot.forecast.averageMonthlyNet, language: language))
            } else {
                summary = language.localized("\(prefix).noHistory")
            }
        case .budgetPressure:
            if !facts.budgets.isEmpty {
                summary = language.localized("\(prefix).summary", Int64(facts.budgets.count), Int64(facts.overBudgetItems.count), Int64(facts.nearLimitItems.count))
            } else {
                summary = language.localized("\(prefix).noBudgets")
            }
        case .aiDiagnostics:
            summary = language.localized(facts.foundationModelsAvailable ? "\(prefix).summary" : "\(prefix).summary.unavailable")
        default:
            summary = language.localized("\(prefix).summary")
        }
        
        var bullets: [String] = []
        for i in 1...4 {
            let key = "\(prefix).bullet\(i)"
            let emptyKey = "\(key).empty"
            
            let val: String?
            switch (intent, i) {
            case (.monthlyBriefing, 2): val = facts.topExpenseCategories.first
            case (.monthlyBriefing, 3): val = facts.topExpenseMerchants.first
            case (.optimizeSpending, 1): val = facts.topExpenseCategories.first
            case (.optimizeSpending, 2): val = facts.recurringCandidates.first
            case (.optimizeSpending, 3): val = facts.topExpenseMerchants.first
            case (.importHealth, 1): val = facts.recentImports.first.map { "\($0.fileName) (\(Int64($0.importedRowCount)))" }
            case (.importHealth, 2): val = facts.recentImports.reduce(0, { $0 + $1.pendingReviewCount }) > 0 ? "" : nil
            case (.uncategorizedScan, 1): val = facts.uncategorizedExamples.isEmpty ? nil : facts.uncategorizedExamples.joined(separator: " · ")
            case (.uncategorizedScan, 2): val = facts.repeatableMerchantsWithoutCategory.first
            case (.recurringMerchants, 1): val = facts.recurringCandidates.isEmpty ? nil : facts.recurringCandidates.joined(separator: " · ")
            case (.analysisPatterns, 1): val = facts.topExpenseCategories.first
            case (.analysisPatterns, 2): val = facts.topExpenseMerchants.first
            case (.analysisPatterns, 3): val = facts.analysisSnapshot.map { formattedCurrency($0.forecast.projectedDelta6Months, language: language) }
            case (.savingsIdeas, 1): val = facts.topExpenseCategories.first
            case (.savingsIdeas, 2): val = facts.recurringCandidates.first
            case (.savingsIdeas, 3): val = facts.overBudgetItems.first.map { budgetLine($0, language: language) }
            case (.reviewPriorities, 1): val = facts.repeatableMerchantsWithoutCategory.first
            case (.reviewPriorities, 2): val = facts.uncategorizedExamples.isEmpty ? nil : facts.uncategorizedExamples.joined(separator: " · ")
            case (.batchResolution, 1): val = facts.repeatableMerchantsWithoutCategory.isEmpty ? nil : facts.repeatableMerchantsWithoutCategory.joined(separator: " · ")
            case (.categoryCleanup, 1): val = facts.emptyCategories.isEmpty ? nil : facts.emptyCategories.prefix(5).joined(separator: " · ")
            case (.categoryCleanup, 2): val = facts.duplicatedCategoryNames.isEmpty ? nil : facts.duplicatedCategoryNames.prefix(5).joined(separator: " · ")
            case (.ruleCandidates, 1): val = facts.repeatableMerchantsWithoutCategory.isEmpty ? nil : facts.repeatableMerchantsWithoutCategory.joined(separator: " · ")
            case (.budgetPressure, 1): val = facts.overBudgetItems.first.map { budgetLine($0, language: language) }
            case (.budgetPressure, 2): val = facts.nearLimitItems.first.map { budgetLine($0, language: language) }
            case (.categoriesOverPlan, 1): val = facts.overBudgetItems.isEmpty ? nil : facts.overBudgetItems.prefix(3).map { budgetLine($0, language: language) }.joined(separator: " · ")
            case (.categoriesOverPlan, 2): val = facts.nearLimitItems.isEmpty ? nil : facts.nearLimitItems.prefix(2).map { budgetLine($0, language: language) }.joined(separator: " · ")
            case (.aiDiagnostics, 1): val = facts.foundationModelsAvailable ? (language == .spanish ? "sí" : "yes") : "no"
            case (.aiDiagnostics, 2): val = String(facts.transactionCount)
            case (.aiDiagnostics, 3): val = "\(facts.categorizedCount)/\(max(facts.transactionCount, 1))"
            case (.aiDiagnostics, 4): val = String(facts.pendingReviewCount)
            case (.learningReadiness, 1): val = formattedPercent(facts.transactionCount == 0 ? 0 : Double(facts.categorizedCount) / Double(facts.transactionCount), language: language)
            case (.learningReadiness, 2): val = String(facts.pendingReviewCount)
            case (.learningReadiness, 3): val = facts.repeatableMerchantsWithoutCategory.first
            default: val = ""
            }
            
            if let v = val {
                if v.isEmpty {
                    bullets.append(language.localized(key))
                } else {
                    bullets.append(language.localized(key, v))
                }
            } else if language.localized(emptyKey) != emptyKey {
                bullets.append(language.localized(emptyKey))
            }
        }
        
        return AppleAIActionResult(title: title, summary: summary, bullets: bullets)
    }

    private func normalizedMerchantName(from transaction: Transaction) -> String {
        let merchant = transaction.merchantCanonicalName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let merchant, !merchant.isEmpty {
            return merchant
        }

        let cleaned = transaction.cleanedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            return cleaned
        }

        return transaction.rawDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func average(_ amounts: [Decimal]) -> Decimal {
        guard !amounts.isEmpty else { return .zero }
        let total = amounts.reduce(Decimal.zero, +)
        return total / Decimal(amounts.count)
    }

    private func currentMonthYear(referenceDate: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: referenceDate)
    }

    private func isCurrentMonth(_ date: Date, referenceDate: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: referenceDate, toGranularity: .month) &&
            calendar.isDate(date, equalTo: referenceDate, toGranularity: .year)
    }

    private func formattedCurrency(_ amount: Decimal, language: AppLanguage = .currentSelection) -> String {
        language.formatCurrency(amount)
    }

    private func formattedPercent(_ value: Double, language: AppLanguage = .currentSelection) -> String {
        language.formatPercent(value)
    }

    private func formattedDate(_ date: Date, language: AppLanguage = .currentSelection) -> String {
        language.format(date: date)
    }

    private func joinedList(_ items: [String], language: AppLanguage = .currentSelection) -> String {
        let filtered = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return filtered.isEmpty ? language.localized("appleAI.noData") : filtered.joined(separator: " | ")
    }

    private func budgetLine(_ item: BudgetPressureItem, language: AppLanguage = .currentSelection) -> String {
        "\(item.categoryName): \(formattedCurrency(item.spent, language: language)) \(language.localized("of %@").replacingOccurrences(of: "%@", with: formattedCurrency(item.limit, language: language))) (\(formattedPercent(item.progress, language: language)))"
    }

    private func decimalToDouble(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    private func absolute(_ decimal: Decimal) -> Decimal {
        decimal < 0 ? -decimal : decimal
    }
}
