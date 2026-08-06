import Foundation
import Observation

@MainActor
@Observable
final class InsightsViewModel {
    // Give the analysis enough context to make trends and scenarios legible.
    // The service anchors the range at the latest reporting month.
    var selectedRange: AnalysisTimeRange = .sixMonths
    var snapshot: FinancialAnalysisSnapshot?
    var planningSnapshot: FinancialPlanningSnapshot?
    var aiNarrative: String?
    var insights: [Insight] = []
    var isLoading = false
    var isGeneratingNarrative = false
    var errorMessage: String?

    func load(using container: AppContainer, language: AppLanguage) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try Task.checkCancellation()
            let transactions = try container.transactionRepository.fetchAll()
            let categories = try container.categoryRepository.fetchAll()
            let accounts = try container.accountRepository.fetchAll()
            let goals = try container.savingsGoalRepository.fetchAll()
            let analysisService = container.financialAnalysisService
            let planningService = container.financialPlanningService
            let range = selectedRange

            let txSnapshots = transactions.map(TransactionSnapshot.init)
            let catSnapshots = categories.map(CategorySnapshot.init)
            let accSnapshots = accounts.map(AccountSnapshot.init)
            let goalSnapshots = goals.map(SavingsGoalSnapshot.init)

            let (computedSnapshot, computedPlanning) = try await Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let txs = txSnapshots.map { $0.toModel() }
                let cats = catSnapshots.map { $0.toModel() }
                let accs = accSnapshots.map { $0.toModel() }
                let gls = goalSnapshots.map { $0.toModel() }
                
                try Task.checkCancellation()
                let snap = analysisService.analyze(
                    transactions: txs,
                    categories: cats,
                    range: range
                )
                let plan = planningService.buildSnapshot(
                    transactions: txs,
                    accounts: accs,
                    goals: gls,
                    categories: cats
                )
                return (snap, plan)
            }.value

            try Task.checkCancellation()
            self.snapshot = computedSnapshot
            self.planningSnapshot = computedPlanning
            self.insights = try container.insightRepository.fetchAll()
            self.errorMessage = nil
            await loadNarrative(using: container, snapshot: computedSnapshot, language: language)
        } catch is CancellationError {
            // Ignore cancellation
            return
        } catch {
            snapshot = nil
            planningSnapshot = nil
            errorMessage = error.localizedDescription
        }
    }

    func refreshRange(_ range: AnalysisTimeRange, using container: AppContainer, language: AppLanguage) async {
        selectedRange = range
        await load(using: container, language: language)
    }

    private func loadNarrative(using container: AppContainer, snapshot: FinancialAnalysisSnapshot, language: AppLanguage) async {
        isGeneratingNarrative = true
        aiNarrative = await container.aiAnalysisSummaryService.summary(for: snapshot, language: language)
        isGeneratingNarrative = false
    }
}
