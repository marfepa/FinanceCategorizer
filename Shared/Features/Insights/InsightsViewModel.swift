import Foundation
import Observation

@MainActor
@Observable
final class InsightsViewModel {
    // Give the analysis enough context to make trends and scenarios legible.
    // The service still anchors the range at the latest accounting month.
    var selectedRange: AnalysisTimeRange = .sixMonths
    var snapshot: FinancialAnalysisSnapshot?
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
            let snapshot = container.financialAnalysisService.analyze(
                transactions: transactions,
                categories: categories,
                range: selectedRange
            )
            self.snapshot = snapshot
            self.insights = try container.insightRepository.fetchAll()
            self.errorMessage = nil
            await loadNarrative(using: container, snapshot: snapshot, language: language)
        } catch {
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
