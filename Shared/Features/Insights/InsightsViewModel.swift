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
            let transactions = try container.transactionRepository.fetchAll()
            let categories = try container.categoryRepository.fetchAll()
            let accounts = try container.accountRepository.fetchAll()
            let goals = try container.savingsGoalRepository.fetchAll()
            let analysisService = container.financialAnalysisService
            let planningService = container.financialPlanningService
            let range = selectedRange

            let (computedSnapshot, computedPlanning) = await Task.detached(priority: .userInitiated) {
                let snap = analysisService.analyze(
                    transactions: transactions,
                    categories: categories,
                    range: range
                )
                let plan = planningService.buildSnapshot(
                    transactions: transactions,
                    accounts: accounts,
                    goals: goals,
                    categories: categories
                )
                return (snap, plan)
            }.value

            self.snapshot = computedSnapshot
            self.planningSnapshot = computedPlanning
            self.insights = try container.insightRepository.fetchAll()
            self.errorMessage = nil
            await loadNarrative(using: container, snapshot: computedSnapshot, language: language)
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
