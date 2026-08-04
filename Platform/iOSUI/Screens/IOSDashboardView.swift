import Charts
import SwiftUI

struct IOSDashboardView: View {
    @Environment(\.appContainer) private var appContainer
    @State private var viewModel = DashboardViewModel()
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @AppStorage("isPrivacyModeEnabled") private var privacyStoredValue = false

    let openImports: () -> Void
    let openTransactions: () -> Void
    let openReview: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    IOSDashboardHero(
                        snapshot: snapshot,
                        renderAmount: renderAmount,
                        appLanguage: appLanguage
                    )

                    IOSDashboardActions(
                        openImports: openImports,
                        openReview: openReview,
                        openTransactions: openTransactions
                    )

                    IOSCashflowCard(
                        snapshot: snapshot,
                        renderAmount: renderAmount,
                        appLanguage: appLanguage
                    )

                    IOSCategoryCard(
                        snapshot: snapshot,
                        renderAmount: renderAmount,
                        appLanguage: appLanguage
                    )

                    IOSAttentionCard(
                        summary: viewModel.copilotSummary,
                        alerts: Array(viewModel.alerts.prefix(2)),
                        pendingReviewCount: snapshot.pendingReviewCount,
                        isLoading: viewModel.isGeneratingCopilot
                    )
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.large)
            } else if viewModel.isLoading {
                LoadingView(title: LocalizedStringKey("Preparing dashboard..."))
                    .padding(.top, AppSpacing.xxxLarge)
            } else {
                EmptyStateView(
                    title: LocalizedStringKey("No Financial Snapshot Yet"),
                    message: LocalizedStringKey("Import real bank movements to see your monthly balance, six-month cashflow and category changes."),
                    systemImage: "rectangle.grid.2x2"
                )
                .padding(.horizontal, AppSpacing.medium)
                .padding(.top, AppSpacing.xxxLarge)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(AppColors.expense)
                    .padding(.horizontal, AppSpacing.medium)
            }
        }
        .background(AppColors.background)
        .navigationTitle(LocalizedStringKey("Dashboard"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    privacyStoredValue.toggle()
                } label: {
                    Image(systemName: privacyStoredValue ? "eye.slash.fill" : "eye.fill")
                }
                .accessibilityLabel(privacyStoredValue ? LocalizedStringKey("Show amounts") : LocalizedStringKey("Hide amounts"))
            }
        }
        .task(id: appLanguage) {
            await viewModel.load(using: appContainer, language: appLanguage)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            Task {
                await viewModel.load(using: appContainer, language: appLanguage)
            }
        }
    }

    private func renderAmount(_ value: Decimal) -> String {
        value.privacyFormatted(hidden: privacyStoredValue, language: appLanguage)
    }
}

private struct IOSDashboardHero: View {
    let snapshot: DashboardSnapshot
    let renderAmount: (Decimal) -> String
    let appLanguage: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(snapshot.monthTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(renderAmount(snapshot.netBalance))
                    .font(AppTypography.heroNumber)
                    .foregroundStyle(snapshot.netBalance >= 0 ? AppColors.income : AppColors.expense)
                    .contentTransition(.numericText())

                Text(LocalizedStringKey("Net result for the latest month"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: AppSpacing.small) {
                IOSMetricTile(
                    title: LocalizedStringKey("Income"),
                    value: renderAmount(snapshot.totalIncome),
                    tint: AppColors.income
                )
                IOSMetricTile(
                    title: LocalizedStringKey("Expenses"),
                    value: renderAmount(snapshot.totalExpenses),
                    tint: AppColors.expense
                )
                IOSMetricTile(
                    title: LocalizedStringKey("Savings Rate"),
                    value: appLanguage.formatPercent(snapshot.savingsRate),
                    tint: snapshot.savingsRate >= 0 ? AppColors.neutral : AppColors.warning
                )
            }

            HStack(alignment: .center, spacing: AppSpacing.small) {
                Image(systemName: snapshot.expenseDeltaFromPreviousMonth > 0 ? "arrow.up.right" : "arrow.down.right")
                    .foregroundStyle(snapshot.expenseDeltaFromPreviousMonth > 0 ? AppColors.warning : AppColors.income)
                Text(expenseSummary)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(padding: AppSpacing.large, radius: AppRadius.hero)
    }

    private var expenseSummary: String {
        guard let delta = snapshot.expenseDeltaPercentage else {
            return appLanguage.localized("dashboard.expenses.noComparison")
        }
        if delta > 0 {
            return appLanguage.localized("dashboard.expenses.up", appLanguage.formatPercent(delta))
        }
        if delta < 0 {
            return appLanguage.localized("dashboard.expenses.down", appLanguage.formatPercent(abs(delta)))
        }
        return appLanguage.localized("dashboard.expenses.same")
    }
}

private struct IOSMetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(padding: AppSpacing.medium, radius: AppRadius.card)
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(tint)
                .frame(width: 34, height: 4)
                .padding(.leading, AppSpacing.medium)
        }
    }
}

private struct IOSDashboardActions: View {
    let openImports: () -> Void
    let openReview: () -> Void
    let openTransactions: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Button(action: openImports) {
                Label(LocalizedStringKey("Import"), systemImage: "square.and.arrow.down")
            }
            .appPrimaryGlassButton()

            Button(action: openReview) {
                Label(LocalizedStringKey("Review"), systemImage: "checklist")
            }
            .appSecondaryGlassButton()

            Button(action: openTransactions) {
                Image(systemName: "list.bullet.rectangle")
                    .frame(width: 42, height: 30)
            }
            .appSecondaryGlassButton()
            .accessibilityLabel(LocalizedStringKey("Open Transactions"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IOSCashflowCard: View {
    let snapshot: DashboardSnapshot
    let renderAmount: (Decimal) -> String
    let appLanguage: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Label(LocalizedStringKey("Income and spending progress"), systemImage: "chart.xyaxis.line")
                    .font(AppTypography.sectionTitle)
                Text(LocalizedStringKey("The last six months, ending with the latest imported month"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if snapshot.monthlyCashflow.isEmpty {
                Text(LocalizedStringKey("Not enough monthly history to visualize cashflow."))
                    .foregroundStyle(.secondary)
            } else {
                Chart(snapshot.monthlyCashflow) { point in
                    BarMark(
                        x: .value("Month", point.monthLabel),
                        y: .value("Amount", decimalValue(point.income))
                    )
                    .foregroundStyle(by: .value("Flow", "Income"))
                    .position(by: .value("Flow", "Income"))

                    BarMark(
                        x: .value("Month", point.monthLabel),
                        y: .value("Amount", decimalValue(point.expense))
                    )
                    .foregroundStyle(by: .value("Flow", "Expenses"))
                    .position(by: .value("Flow", "Expenses"))

                    LineMark(
                        x: .value("Month", point.monthLabel),
                        y: .value("Net", decimalValue(point.net))
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(by: .value("Flow", "Net"))
                }
                .frame(height: 220)
                .chartForegroundStyleScale([
                    "Income": AppColors.income,
                    "Expenses": AppColors.expense,
                    "Net": AppColors.neutral
                ])
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: AppSpacing.small)
            }

            if let latest = snapshot.monthlyCashflow.last {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(appLanguage.localized("dashboard.cashflow.latest", latest.monthLabel))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: AppSpacing.medium) {
                        summaryText(title: LocalizedStringKey("Income"), value: renderAmount(latest.income), tint: AppColors.income)
                        summaryText(title: LocalizedStringKey("Expenses"), value: renderAmount(latest.expense), tint: AppColors.expense)
                        summaryText(title: LocalizedStringKey("Net"), value: renderAmount(latest.net), tint: latest.net >= 0 ? AppColors.neutral : AppColors.warning)
                    }
                }
            }
        }
        .contentCard()
    }

    private func summaryText(title: LocalizedStringKey, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func decimalValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

private struct IOSCategoryCard: View {
    let snapshot: DashboardSnapshot
    let renderAmount: (Decimal) -> String
    let appLanguage: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Label(LocalizedStringKey("Where the money goes"), systemImage: "chart.bar.fill")
                    .font(AppTypography.sectionTitle)
                Text(LocalizedStringKey("The biggest categories and the ones accelerating"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if snapshot.topCategories.isEmpty {
                Text(LocalizedStringKey("No categorized expenses yet this month."))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: AppSpacing.medium) {
                    ForEach(Array(snapshot.topCategories.prefix(5))) { item in
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            HStack {
                                Text(item.name)
                                    .font(.headline)
                                Spacer()
                                Text(renderAmount(item.amount))
                                    .font(.callout.weight(.semibold))
                            }

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.08))
                                    Capsule()
                                        .fill(AppColors.neutral.gradient)
                                        .frame(width: max(10, proxy.size.width * min(max(item.share, 0.02), 1)))
                                }
                            }
                            .frame(height: 7)
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(LocalizedStringKey("What has changed"))
                    .font(.headline)

                let growingCategories = snapshot.categoryChanges.filter { $0.deltaFromPreviousMonth > 0 }.prefix(4)
                if growingCategories.isEmpty {
                    Text(LocalizedStringKey("No category is above the previous month."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(growingCategories)) { item in
                        HStack(alignment: .top, spacing: AppSpacing.small) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .foregroundStyle(AppColors.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(changeCaption(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+\(renderAmount(item.deltaFromPreviousMonth))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.warning)
                        }
                    }
                }
            }
        }
        .contentCard()
    }

    private func changeCaption(for item: DashboardCategoryItem) -> String {
        if item.previousAmount == .zero {
            return appLanguage.localized("dashboard.category.new")
        }
        guard let deltaPercentage = item.deltaPercentage else {
            return appLanguage.localized("dashboard.category.amountUp", renderAmount(item.deltaFromPreviousMonth))
        }
        return appLanguage.localized("dashboard.category.percentUp", appLanguage.formatPercent(deltaPercentage))
    }
}

private struct IOSAttentionCard: View {
    let summary: String?
    let alerts: [String]
    let pendingReviewCount: Int
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Label(LocalizedStringKey("What deserves attention"), systemImage: "sparkles")
                    .font(AppTypography.sectionTitle)
                Spacer()
                if pendingReviewCount > 0 {
                    Text(LocalizedStringKey("Review needed"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.warning)
                }
            }

            if isLoading {
                ProgressView()
            } else {
                if let summary {
                    Text(summary)
                        .font(.subheadline)
                        .lineSpacing(3)
                } else {
                    Text(LocalizedStringKey("No additional briefing available yet."))
                        .foregroundStyle(.secondary)
                }

                if !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(LocalizedStringKey("Alerts"))
                            .font(.headline)
                            .foregroundStyle(AppColors.warning)
                        ForEach(alerts, id: \.self) { alert in
                            Label(alert, systemImage: "exclamationmark.circle.fill")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .contentCard()
    }
}
