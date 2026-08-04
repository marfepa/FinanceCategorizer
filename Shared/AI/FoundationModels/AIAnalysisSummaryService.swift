import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AIAnalysisSummaryService {
    private let availabilityService: AIAvailabilityService

    init(availabilityService: AIAvailabilityService) {
        self.availabilityService = availabilityService
    }

    func summary(for snapshot: FinancialAnalysisSnapshot, language: AppLanguage) async -> String? {
        #if canImport(FoundationModels)
        guard availabilityService.isAvailable() else {
            return deterministicSummary(for: snapshot, language: language)
        }

        if #available(macOS 26.0, iOS 26.0, *) {
            let session = LanguageModelSession()

            let prompt = """
            You are an analytical household finance copilot.
            Summarize the current financial situation in 4 concise bullet points.
            Mention income, expenses, trends, forecast risk, and review queue impact.
            
            IMPORTANT: Your entire response MUST be in \(language.title).

            Income: \(snapshot.totalIncome)
            Expenses: \(snapshot.totalExpenses)
            Net balance: \(snapshot.netBalance)
            Savings rate: \(snapshot.savingsRate)
            Categorized percentage: \(snapshot.categorizedPercentage)
            Pending review: \(snapshot.pendingReviewCount)
            Average monthly net: \(snapshot.forecast.averageMonthlyNet)
            Forecast history months: \(snapshot.forecast.sourceMonthCount)
            Forecast 3 months: \(snapshot.forecast.projectedDelta3Months)
            Forecast 6 months: \(snapshot.forecast.projectedDelta6Months)
            Forecast 12 months: \(snapshot.forecast.projectedDelta12Months)
            Top categories: \(snapshot.categoryBreakdown.prefix(5).map { "\($0.categoryName)=\($0.amount)" }.joined(separator: ", "))
            Recurring expenses: \(snapshot.recurringExpenses.prefix(5).map { "\($0.concept)=\($0.averageAmount)" }.joined(separator: ", "))
            """

            do {
                let response = try await session.respond(to: prompt)
                return String(describing: response.content)
            } catch {
                return deterministicSummary(for: snapshot, language: language)
            }
        }
        #endif

        return deterministicSummary(for: snapshot, language: language)
    }

    private func deterministicSummary(for snapshot: FinancialAnalysisSnapshot, language: AppLanguage) -> String {
        let isPositive = NSDecimalNumber(decimal: snapshot.netBalance).doubleValue >= 0
        let deltaLine = isPositive ? language.localized("analysis.summary.deltaPositive") : language.localized("analysis.summary.deltaNegative")
        
        let topCategory = snapshot.categoryBreakdown.first?.categoryName ?? language.localized("Sin categorizar")
        let topCategoryLine = language.localized("analysis.summary.topCategory", topCategory)
        
        let pendingLine = language.localized("analysis.summary.pendingReview", Int64(snapshot.pendingReviewCount))
        
        let riskKey: String
        if snapshot.forecast.hasLimitedHistory {
            riskKey = "analysis.summary.riskLimited"
        } else {
            riskKey = snapshot.forecast.isNegativeTrend
                ? "analysis.summary.riskNegative"
                : "analysis.summary.riskSustainable"
        }
        let riskLine = "- \(language.localized(riskKey))"
        
        return """
        \(deltaLine)
        \(topCategoryLine)
        \(pendingLine)
        \(riskLine)
        """
    }
}
