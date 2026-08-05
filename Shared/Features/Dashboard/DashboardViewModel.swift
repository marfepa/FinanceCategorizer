import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    var snapshot: DashboardSnapshot?
    var planningSnapshot: FinancialPlanningSnapshot?
    var copilotSummary: String?
    var alerts: [String] = []
    var actions: [String] = []
    var isLoading = false
    var isGeneratingCopilot = false
    var errorMessage: String?

    func load(using container: AppContainer, language: AppLanguage) async {
        isLoading = true
        defer {
            isLoading = false
            isGeneratingCopilot = false
        }

        do {
            let transactions = try container.transactionRepository.fetchAll()
            let categories = try container.categoryRepository.fetchAll()
            let accounts = try container.accountRepository.fetchAll()
            let goals = try container.savingsGoalRepository.fetchAll()
            let recentImports = try container.importBatchRepository.fetchRecentBatches(limit: 6)

            let dashboardService = container.dashboardInsightService
            let planningService = container.financialPlanningService
            let locale = language.locale

            let (computedSnapshot, computedPlanning) = await Task.detached(priority: .userInitiated) {
                let snap = dashboardService.buildSnapshot(
                    transactions: transactions,
                    categories: categories,
                    recentImports: recentImports,
                    locale: locale,
                    dateBasis: .budget
                )
                let plan = planningService.buildSnapshot(
                    transactions: transactions,
                    accounts: accounts,
                    goals: goals,
                    categories: categories
                )
                return (snap, plan)
            }.value

            snapshot = computedSnapshot
            planningSnapshot = computedPlanning
            errorMessage = nil

            guard let snapshot else {
                copilotSummary = nil
                alerts = []
                actions = []
                return
            }

            isGeneratingCopilot = true
            let copilot = await container.aiDashboardCopilotService.generate(for: snapshot, language: language)
            copilotSummary = copilot.summary
            alerts = copilot.alerts
            actions = copilot.recommendedActions
        } catch {
            snapshot = nil
            planningSnapshot = nil
            copilotSummary = nil
            alerts = []
            actions = []
            errorMessage = error.localizedDescription
        }
    }
}
