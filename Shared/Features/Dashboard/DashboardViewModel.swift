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
            try Task.checkCancellation()
            let transactions = try container.transactionRepository.fetchAll()
            let categories = try container.categoryRepository.fetchAll()
            let accounts = try container.accountRepository.fetchAll()
            let goals = try container.savingsGoalRepository.fetchAll()
            let recentImports = try container.importBatchRepository.fetchRecentBatches(limit: 6)

            let txSnapshots = transactions.map(TransactionSnapshot.init)
            let catSnapshots = categories.map(CategorySnapshot.init)
            let accSnapshots = accounts.map(AccountSnapshot.init)
            let goalSnapshots = goals.map(SavingsGoalSnapshot.init)
            let importSnapshots = recentImports.map(ImportBatchSnapshot.init)

            let dashboardService = container.dashboardInsightService
            let planningService = container.financialPlanningService
            let locale = language.locale

            let (computedSnapshot, computedPlanning) = try await Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let txs = txSnapshots.map { $0.toModel() }
                let cats = catSnapshots.map { $0.toModel() }
                let accs = accSnapshots.map { $0.toModel() }
                let gls = goalSnapshots.map { $0.toModel() }
                let imps = importSnapshots.map { $0.toModel() }

                try Task.checkCancellation()
                let snap = dashboardService.buildSnapshot(
                    transactions: txs,
                    categories: cats,
                    recentImports: imps,
                    locale: locale,
                    dateBasis: .budget
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
            try Task.checkCancellation()
            
            copilotSummary = copilot.summary
            alerts = copilot.alerts
            actions = copilot.recommendedActions
        } catch is CancellationError {
            // Ignore cancellation gracefully
            return
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
