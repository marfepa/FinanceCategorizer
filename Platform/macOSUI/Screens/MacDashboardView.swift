import Charts
import SwiftUI

struct MacDashboardView: View {
    @Environment(\.appContainer) private var appContainer
    @State private var viewModel = DashboardViewModel()
    @AppStorage("isPrivacyModeEnabled") private var privacyStoredValue = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english

    let openImports: () -> Void
    let openTransactions: () -> Void
    let openReview: () -> Void

    private let chartPalette: [Color] = [
        Color(hue: 0.60, saturation: 0.70, brightness: 0.92),
        Color(hue: 0.44, saturation: 0.65, brightness: 0.82),
        Color(hue: 0.10, saturation: 0.75, brightness: 0.96),
        Color(hue: 0.97, saturation: 0.60, brightness: 0.88),
        Color(hue: 0.72, saturation: 0.55, brightness: 0.90)
    ]

    var body: some View {
        GlassPageScaffold {
            header
        } content: {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                    DashboardHeroPanel(
                        snapshot: snapshot,
                        renderAmount: renderAmount,
                        renderPercent: { appLanguage.formatPercent($0) },
                        expenseSummary: expenseSummary(for: snapshot),
                        appLanguage: appLanguage
                    )

                    DashboardActionBar(
                        openImports: openImports,
                        openReview: openReview,
                        openTransactions: openTransactions
                    )

                    DashboardCashflowCard(
                        snapshot: snapshot,
                        decimalValue: decimalValue,
                        renderAmount: renderAmount,
                        appLanguage: appLanguage
                    )

                    DashboardCategoryOverviewCard(
                        snapshot: snapshot,
                        chartPalette: chartPalette,
                        renderAmount: renderAmount,
                        appLanguage: appLanguage,
                        decimalValue: decimalValue
                    )

                    DashboardBriefingCard(
                        summary: viewModel.copilotSummary,
                        alerts: Array(viewModel.alerts.prefix(2)),
                        actions: Array(viewModel.actions.prefix(2)),
                        pendingReviewCount: snapshot.pendingReviewCount,
                        uncategorizedExpenseCount: snapshot.uncategorizedExpenseCount,
                        uncategorizedExpenseAmount: snapshot.uncategorizedExpenseAmount,
                        renderAmount: renderAmount,
                        isLoading: viewModel.isGeneratingCopilot
                    )
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if viewModel.isLoading {
                LoadingView(title: LocalizedStringKey("Preparing dashboard..."))
            } else {
                EmptyStateView(
                    title: LocalizedStringKey("No Financial Snapshot Yet"),
                    message: LocalizedStringKey("Import real bank movements to see your monthly balance, six-month cashflow and category changes."),
                    systemImage: "rectangle.grid.2x2"
                )
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(AppColors.expense)
                    .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.card)
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppLayoutMetrics.contentGap) {
            VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                Text(LocalizedStringKey("Family Overview"))
                    .font(AppTypography.displayTitle)
                Text(LocalizedStringKey("See what came in, what went out and where the household budget is changing."))
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Button {
                privacyStoredValue.toggle()
            } label: {
                Label(
                    privacyStoredValue ? LocalizedStringKey("Amounts hidden") : LocalizedStringKey("Amounts visible"),
                    systemImage: privacyStoredValue ? "eye.slash.fill" : "eye.fill"
                )
                .font(.caption.weight(.semibold))
            }
            .appSecondaryGlassButton()
            .controlSize(.small)
            .help(privacyStoredValue ? LocalizedStringKey("Show amounts") : LocalizedStringKey("Hide amounts"))
        }
    }

    private func expenseSummary(for snapshot: DashboardSnapshot) -> String {
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

    private func renderAmount(_ value: Decimal) -> String {
        value.privacyFormatted(hidden: privacyStoredValue, language: appLanguage)
    }

    private func decimalValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

private struct DashboardHeroPanel: View {
    let snapshot: DashboardSnapshot
    let renderAmount: (Decimal) -> String
    let renderPercent: (Double) -> String
    let expenseSummary: String
    let appLanguage: AppLanguage

    var body: some View {
        HStack(alignment: .top, spacing: AppLayoutMetrics.sectionGap) {
            VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
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

                HStack(spacing: AppLayoutMetrics.contentGap) {
                    DashboardHeroMetric(
                        title: LocalizedStringKey("Income"),
                        value: renderAmount(snapshot.totalIncome),
                        tint: AppColors.income
                    )
                    DashboardHeroMetric(
                        title: LocalizedStringKey("Expenses"),
                        value: renderAmount(snapshot.totalExpenses),
                        tint: AppColors.expense
                    )
                    DashboardHeroMetric(
                        title: LocalizedStringKey("Savings Rate"),
                        value: renderPercent(snapshot.savingsRate),
                        tint: snapshot.savingsRate >= 0 ? AppColors.neutral : AppColors.warning
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
                Label(LocalizedStringKey("Month signal"), systemImage: "waveform.path.ecg")
                    .font(AppTypography.sectionTitle)

                Text(expenseSummary)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(snapshot.expenseDeltaFromPreviousMonth > 0 ? AppColors.warning : AppColors.income)
                    .fixedSize(horizontal: false, vertical: true)

                Text(LocalizedStringKey("Compared with the previous month"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label(netTrendTitle, systemImage: netTrendIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(netTrendColor)

                if snapshot.expenseDeltaPercentage != nil,
                   snapshot.expenseDeltaFromPreviousMonth < .zero,
                   snapshot.netTrend == .decreasing {
                    Text(LocalizedStringKey("dashboard.netTrend.explanation"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let netDelta = snapshot.netDeltaFromPreviousMonth {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("Net change"))
                        Text(renderAmount(netDelta))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text(LocalizedStringKey("Expense coverage"))
                    Text(renderPercent(snapshot.dataQuality.expenseCategorizationCoverage))
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if snapshot.dataQuality.internalTransferCount > 0 {
                    Text(appLanguage.localized(
                        "dashboard.transferExclusion",
                        appLanguage.formatInteger(snapshot.dataQuality.internalTransferCount)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if snapshot.pendingReviewCount > 0 {
                    Label(
                        LocalizedStringKey("Some numbers still need review"),
                        systemImage: "exclamationmark.bubble.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.warning)
                } else {
                    Label(
                        LocalizedStringKey("All latest movements are reviewed"),
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.income)
                }
            }
            .frame(width: 290, alignment: .topLeading)
            .contentCard(padding: AppLayoutMetrics.blockGap, radius: AppRadius.card)
        }
        .contentCard(padding: AppLayoutMetrics.heroInset, radius: AppRadius.hero)
    }

    private var netTrendTitle: LocalizedStringKey {
        switch snapshot.netTrend {
        case .increasing: return "Net trend increasing"
        case .decreasing: return "Net trend decreasing"
        case .stable: return "Net trend stable"
        case .insufficientData: return "Not enough data for net trend"
        }
    }

    private var netTrendIcon: String {
        switch snapshot.netTrend {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "equal"
        case .insufficientData: return "questionmark"
        }
    }

    private var netTrendColor: Color {
        switch snapshot.netTrend {
        case .increasing: return AppColors.income
        case .decreasing: return AppColors.warning
        case .stable, .insufficientData: return AppColors.neutral
        }
    }
}

private struct DashboardHeroMetric: View {
    let title: LocalizedStringKey
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppLayoutMetrics.contentGap)
        .padding(.vertical, 12)
        .liquidGlassPill(padding: 0, tint: tint)
    }
}

private struct DashboardActionBar: View {
    let openImports: () -> Void
    let openReview: () -> Void
    let openTransactions: () -> Void

    var body: some View {
        GlassActionStrip {
            PrimaryButton(title: LocalizedStringKey("Import File"), action: openImports)
            PrimaryButton(title: LocalizedStringKey("Review Queue"), action: openReview)
        } secondary: {
            Button(LocalizedStringKey("Open Transactions"), action: openTransactions)
                .appSecondaryGlassButton()
        }
    }
}

private struct DashboardCashflowCard: View {
    let snapshot: DashboardSnapshot
    let decimalValue: (Decimal) -> Double
    let renderAmount: (Decimal) -> String
    let appLanguage: AppLanguage
    @State private var selectedMonthLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                    Label(LocalizedStringKey("Income and spending progress"), systemImage: "chart.xyaxis.line")
                        .font(AppTypography.sectionTitle)
                    Text(LocalizedStringKey("The last six months, ending with the latest imported month"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let latest = snapshot.monthlyCashflow.last {
                    Text(appLanguage.localized("dashboard.cashflow.latest", latest.monthLabel))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                }
                .frame(height: 270)
                .chartForegroundStyleScale([
                    "Income": AppColors.income,
                    "Expenses": AppColors.expense,
                    "Net": AppColors.neutral
                ])
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartLegend(position: .top, alignment: .leading, spacing: AppLayoutMetrics.contentGap)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        guard let plotFrameAnchor = proxy.plotFrame else { return }
                                        let plotFrame = geometry[plotFrameAnchor]
                                        let xPosition = value.location.x - plotFrame.origin.x
                                        guard xPosition >= 0,
                                              xPosition <= plotFrame.size.width,
                                              let label: String = proxy.value(atX: xPosition, as: String.self) else {
                                            return
                                        }
                                        selectedMonthLabel = label
                                    }
                            )
                    }
                }

                if let selectedMonthLabel,
                   let selectedPoint = snapshot.monthlyCashflow.first(where: { $0.monthLabel == selectedMonthLabel }) {
                    InteractiveChartReadout(
                        title: selectedPoint.monthLabel,
                        values: [
                            (appLanguage.localized("Income"), renderAmount(selectedPoint.income)),
                            (appLanguage.localized("Expenses"), renderAmount(selectedPoint.expense)),
                            (appLanguage.localized("Net"), renderAmount(selectedPoint.net))
                        ]
                    )
                }
            }

            if let latest = snapshot.monthlyCashflow.last {
                HStack(spacing: AppLayoutMetrics.contentGap) {
                    cashflowReading(
                        title: LocalizedStringKey("Latest income"),
                        value: renderAmount(latest.income),
                        tint: AppColors.income
                    )
                    cashflowReading(
                        title: LocalizedStringKey("Latest expenses"),
                        value: renderAmount(latest.expense),
                        tint: AppColors.expense
                    )
                    cashflowReading(
                        title: LocalizedStringKey("Latest net"),
                        value: renderAmount(latest.net),
                        tint: latest.net >= 0 ? AppColors.neutral : AppColors.warning
                    )
                }
            }
        }
        .contentCard()
    }

    private func cashflowReading(title: LocalizedStringKey, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DashboardCategoryOverviewCard: View {
    let snapshot: DashboardSnapshot
    let chartPalette: [Color]
    let renderAmount: (Decimal) -> String
    let appLanguage: AppLanguage
    let decimalValue: (Decimal) -> Double

    var body: some View {
        HStack(alignment: .top, spacing: AppLayoutMetrics.sectionGap) {
            DashboardTopCategoriesColumn(
                categories: Array(snapshot.topCategories.prefix(5)),
                chartPalette: chartPalette,
                renderAmount: renderAmount,
                decimalValue: decimalValue
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)

            DashboardCategoryChangesColumn(
                categories: Array(snapshot.categoryChanges.filter { $0.deltaFromPreviousMonth > 0 }.prefix(5)),
                renderAmount: renderAmount,
                appLanguage: appLanguage
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .contentCard()
    }
}

private struct DashboardTopCategoriesColumn: View {
    let categories: [DashboardCategoryItem]
    let chartPalette: [Color]
    let renderAmount: (Decimal) -> String
    let decimalValue: (Decimal) -> Double

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            Label(LocalizedStringKey("Where the money goes"), systemImage: "chart.bar.fill")
                .font(AppTypography.sectionTitle)

            if categories.isEmpty {
                Text(LocalizedStringKey("No categorized expenses yet this month."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                        HStack {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(chartPalette[index % chartPalette.count])
                                    .frame(width: 10, height: 10)
                                Text(item.name)
                                    .font(.headline)
                            }
                            Spacer()
                            Text(renderAmount(item.amount))
                                .font(.headline)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.06))
                                Capsule()
                                    .fill(chartPalette[index % chartPalette.count].gradient)
                                    .frame(width: max(12, proxy.size.width * min(max(item.share, 0.02), 1)))
                            }
                        }
                        .frame(height: 8)

                        Text(item.share.formatted(.percent.precision(.fractionLength(0))))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct DashboardCategoryChangesColumn: View {
    let categories: [DashboardCategoryItem]
    let renderAmount: (Decimal) -> String
    let appLanguage: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            Label(LocalizedStringKey("What has changed"), systemImage: "arrow.up.right.circle.fill")
                .font(AppTypography.sectionTitle)

            Text(LocalizedStringKey("Categories growing versus the previous month"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if categories.isEmpty {
                Text(LocalizedStringKey("No category is above the previous month."))
                    .foregroundStyle(.secondary)
                    .padding(.top, AppLayoutMetrics.microGap)
            } else {
                ForEach(categories) { item in
                    HStack(alignment: .top, spacing: AppLayoutMetrics.contentGap) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.warning)
                            .frame(width: 28, height: 28)
                            .liquidGlassPill(padding: 0, tint: AppColors.warning)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.headline)
                            Text(changeCaption(for: item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("+\(renderAmount(item.deltaFromPreviousMonth))")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(AppColors.warning)
                    }
                    .padding(.vertical, AppLayoutMetrics.microGap)
                }
            }
        }
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

private struct DashboardBriefingCard: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    let summary: String?
    let alerts: [String]
    let actions: [String]
    let pendingReviewCount: Int
    let uncategorizedExpenseCount: Int
    let uncategorizedExpenseAmount: Decimal
    let renderAmount: (Decimal) -> String
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            HStack(alignment: .center) {
                Label(LocalizedStringKey("What deserves attention"), systemImage: "sparkles")
                    .font(AppTypography.sectionTitle)
                Spacer()
                if pendingReviewCount > 0 {
                    Text(LocalizedStringKey("Review needed"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.warning)
                        .liquidGlassPill(padding: 10, tint: AppColors.warning)
                }
            }

            if isLoading {
                HStack(spacing: AppLayoutMetrics.contentGap) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LocalizedStringKey("Preparing your household briefing..."))
                        .foregroundStyle(.secondary)
                }
            } else {
                if let summary {
                    Text(summary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
                } else {
                    Text(LocalizedStringKey("No additional briefing available yet."))
                        .foregroundStyle(.secondary)
                }

                if uncategorizedExpenseCount > 0 {
                Text(
                    appLanguage.localized(
                        "dashboard.confidence.uncategorized",
                        appLanguage.formatInteger(uncategorizedExpenseCount),
                        renderAmount(uncategorizedExpenseAmount)
                    )
                )
                .font(.footnote)
                .foregroundStyle(AppColors.warning)
                }

                HStack(alignment: .top, spacing: AppLayoutMetrics.sectionGap) {
                    conciseColumn(
                        title: LocalizedStringKey("Alerts"),
                        tint: AppColors.warning,
                        items: alerts,
                        emptyText: LocalizedStringKey("No important alerts right now.")
                    )
                    conciseColumn(
                        title: LocalizedStringKey("Next Actions"),
                        tint: AppColors.neutral,
                        items: actions,
                        emptyText: LocalizedStringKey("No actions suggested right now.")
                    )
                }
            }
        }
        .contentCard()
    }

    private func conciseColumn(title: LocalizedStringKey, tint: Color, items: [String], emptyText: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            Text(title)
                .font(.headline)
                .foregroundStyle(tint)

            if items.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: AppLayoutMetrics.microGap) {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
