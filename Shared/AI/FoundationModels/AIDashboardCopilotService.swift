import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct DashboardCopilotOutput {
    let summary: String
    let alerts: [String]
    let recommendedActions: [String]
}

struct AIDashboardCopilotService {
    private let availabilityService: AIAvailabilityService

    init(availabilityService: AIAvailabilityService) {
        self.availabilityService = availabilityService
    }

    func generate(for snapshot: DashboardSnapshot, language: AppLanguage) async -> DashboardCopilotOutput {
        #if canImport(FoundationModels)
        if availabilityService.isAvailable() {
            if #available(macOS 26.0, iOS 26.0, *) {
                let session = LanguageModelSession()
                    let dominantCategory = snapshot.dominantCategoryName ?? "None"
                    let expenseDeltaPercentageText = snapshot.expenseDeltaPercentage.map { String($0) } ?? "n/a"
                    let topCategoriesText = snapshot.topCategories
                        .map { "\($0.name)=\($0.amount)" }
                        .joined(separator: ", ")
                    let recentImportsText = snapshot.recentImports
                        .map { "\($0.fileName)=\($0.importedRowCount)" }
                        .joined(separator: ", ")
                    let prompt = """
                    You are a household finance dashboard copilot.
                    Use only the provided facts. Be concise, practical and non-technical.
                    Respond in \(language.title).
                    Reply with exactly these lines:
                    SUMMARY: <2-4 short sentences>
                    ALERTS: <up to 3 short alerts separated by |>
                    ACTIONS: <up to 3 short actions separated by |>

                    Month: \(snapshot.monthTitle)
                    Income: \(snapshot.totalIncome)
                    Expenses: \(snapshot.totalExpenses)
                    Net: \(snapshot.netBalance)
                    Savings rate: \(snapshot.savingsRate)
                    Categorized: \(snapshot.categorizedPercentage)
                    Pending review: \(snapshot.pendingReviewCount)
                    Dominant category: \(dominantCategory)
                    Expense delta vs previous month: \(snapshot.expenseDeltaFromPreviousMonth)
                    Expense delta percentage: \(expenseDeltaPercentageText)
                    Top categories: \(topCategoriesText)
                    Recent imports: \(recentImportsText)
                    """

                    do {
                        let response = try await session.respond(to: prompt)
                        if let parsed = parse(String(describing: response.content)) {
                            return parsed
                        }
                    } catch {
                        return deterministicOutput(for: snapshot, language: language)
                    }
            }
        }
        #endif

        return deterministicOutput(for: snapshot, language: language)
    }

    private func parse(_ text: String) -> DashboardCopilotOutput? {
        let lines = text.components(separatedBy: .newlines)
        let summary = lines.first(where: { $0.uppercased().hasPrefix("SUMMARY:") })?
            .split(separator: ":", maxSplits: 1).last.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let alerts = lines.first(where: { $0.uppercased().hasPrefix("ALERTS:") })?
            .split(separator: ":", maxSplits: 1).last.map(String.init)?
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        let actions = lines.first(where: { $0.uppercased().hasPrefix("ACTIONS:") })?
            .split(separator: ":", maxSplits: 1).last.map(String.init)?
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        guard let summary, !summary.isEmpty else { return nil }
        return DashboardCopilotOutput(
            summary: summary,
            alerts: Array(alerts.prefix(3)),
            recommendedActions: Array(actions.prefix(3))
        )
    }

    private func deterministicOutput(for snapshot: DashboardSnapshot, language: AppLanguage) -> DashboardCopilotOutput {
        let summary = buildSummary(for: snapshot, language: language)
        let alerts = buildAlerts(for: snapshot, language: language)
        let actions = buildActions(for: snapshot, language: language)

        return DashboardCopilotOutput(
            summary: summary,
            alerts: Array(alerts.prefix(3)),
            recommendedActions: Array(actions.prefix(3))
        )
    }

    private func buildSummary(for snapshot: DashboardSnapshot, language: AppLanguage) -> String {
        let netIsPositive = NSDecimalNumber(decimal: snapshot.netBalance).doubleValue >= 0
        let dominant = snapshot.dominantCategoryName ?? language.localized("Sin categorizar")
        let deltaText: String
        if let delta = snapshot.expenseDeltaPercentage {
            deltaText = delta >= 0
                ? language.localized("dashboard.copilot.spendingUp", language.formatPercent(delta))
                : language.localized("dashboard.copilot.spendingDown", language.formatPercent(abs(delta)))
        } else {
            deltaText = language.localized("There is not enough previous-month data to compare spending.")
        }

        return netIsPositive
            ? language.localized("dashboard.copilot.summaryPositive", snapshot.monthTitle, deltaText, dominant.lowercased())
            : language.localized("dashboard.copilot.summaryNegative", snapshot.monthTitle, deltaText, dominant.lowercased())
    }

    private func buildAlerts(for snapshot: DashboardSnapshot, language: AppLanguage) -> [String] {
        var alerts: [String] = []

        if NSDecimalNumber(decimal: snapshot.netBalance).doubleValue < 0 {
            alerts.append(language.localized("Net balance is negative this month."))
        }

        if let delta = snapshot.expenseDeltaPercentage, delta > 0.15 {
            alerts.append(language.localized("Expenses are rising noticeably versus the previous month."))
        }

        if snapshot.pendingReviewCount >= 5 {
            alerts.append(language.localized("Several movements are still pending review and may distort the picture."))
        }

        if snapshot.categorizedPercentage < 0.75 {
            alerts.append(language.localized("A significant part of the month is still weakly categorized."))
        }

        if let topCategory = snapshot.topCategories.first, topCategory.share > 0.35 {
            alerts.append(language.localized("dashboard.copilot.topCategoryAlert", topCategory.name))
        }

        return alerts
    }

    private func buildActions(for snapshot: DashboardSnapshot, language: AppLanguage) -> [String] {
        var actions: [String] = []

        if snapshot.pendingReviewCount > 0 {
            actions.append(language.localized("Review the pending movements to stabilize the dashboard numbers."))
        }

        if snapshot.categorizedPercentage < 0.75 {
            actions.append(language.localized("Confirm ambiguous categories so the monthly picture becomes more reliable."))
        }

        if NSDecimalNumber(decimal: snapshot.netBalance).doubleValue < 0 {
            actions.append(language.localized("Open Analysis to inspect which categories are pushing the month negative."))
        }

        if let delta = snapshot.expenseDeltaPercentage, delta > 0.15 {
            actions.append(language.localized("Check the top categories to understand the spending spike versus last month."))
        }

        if actions.isEmpty {
            actions.append(language.localized("Keep importing and reviewing movements to preserve a reliable monthly snapshot."))
        }

        return actions
    }
}
