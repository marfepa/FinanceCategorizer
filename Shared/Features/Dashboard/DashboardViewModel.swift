import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    var snapshot: DashboardSnapshot?
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
            let recentImports = try container.importBatchRepository.fetchRecentBatches(limit: 6)

            snapshot = container.dashboardInsightService.buildSnapshot(
                transactions: transactions,
                categories: categories,
                recentImports: recentImports,
                locale: language.locale,
                dateBasis: .accounting
            )
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
            copilotSummary = nil
            alerts = []
            actions = []
            errorMessage = error.localizedDescription
        }
    }
}
