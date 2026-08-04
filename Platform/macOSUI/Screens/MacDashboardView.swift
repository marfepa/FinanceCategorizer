import Charts
import SwiftUI

struct MacDashboardView: View {
    @Environment(\.appContainer) private var appContainer
    @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled
    @State private var viewModel = DashboardViewModel()
    @AppStorage("isPrivacyModeEnabled") private var privacyStoredValue = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english

    let openImports: () -> Void
    let openTransactions: () -> Void
    let openInsights: () -> Void
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
        } background: {
            dashboardAtmosphere
        } content: {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                    DashboardHeroPanel(
                        snapshot: snapshot,
                        renderAmount: renderAmount,
                        heroSubtitle: heroSubtitle,
                        deltaCaption: deltaCaption,
                        decimalValue: decimalValue
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))

                    DashboardActionBar(
                        openImports: openImports,
                        openReview: openReview,
                        openTransactions: openTransactions
                    )

                    DashboardKPIStrip(
                        snapshot: snapshot,
                        renderAmount: renderAmount,
                        appLanguage: appLanguage
                    )

                    DashboardCopilotCard(
                        summary: viewModel.copilotSummary,
                        alerts: Array(viewModel.alerts.prefix(2)),
                        actions: Array(viewModel.actions.prefix(2)),
                        isLoading: viewModel.isGeneratingCopilot,
                        openInsights: openInsights
                    )

                    HStack(alignment: .top, spacing: AppLayoutMetrics.blockGap) {
                        DashboardCategoryPressureCard(
                            snapshot: snapshot,
                            chartPalette: chartPalette,
                            renderAmount: renderAmount,
                            decimalValue: decimalValue
                        )
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
                            DashboardRecentImportsCard(snapshot: snapshot)
                            DashboardConfidenceCard(snapshot: snapshot, renderAmount: renderAmount)
                        }
                        .frame(width: 320, alignment: .topLeading)
                    }
                }
            } else if viewModel.isLoading {
                LoadingView(title: LocalizedStringKey("Preparing dashboard..."))
            } else {
                EmptyStateView(
                    title: LocalizedStringKey("No Financial Snapshot Yet"),
                    message: LocalizedStringKey("Import real bank movements to see your monthly balance, AI briefing and top household spending categories."),
                    systemImage: "rectangle.stack.badge.person.crop"
                )
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
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

    private var dashboardAtmosphere: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        AppColors.background,
                        Color.white.opacity(0.03),
                        AppColors.background.opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .backgroundExtensionEffect()
            .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppLayoutMetrics.contentGap) {
            VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                Text(LocalizedStringKey("Dashboard"))
                    .font(AppTypography.displayTitle)
                Text(LocalizedStringKey("Understand the month in one glance: net balance, pressure points and the next best move."))
                    .foregroundStyle(.secondary)
            }

            Spacer()
            privacyToggle
        }
    }

    private var privacyToggle: some View {
        Button {
            privacyStoredValue.toggle()
        } label: {
            Image(systemName: privacyStoredValue ? "eye.slash.fill" : "eye.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(privacyStoredValue ? LocalizedStringKey("Show amounts") : LocalizedStringKey("Hide amounts"))
    }

    private func heroSubtitle(_ snapshot: DashboardSnapshot) -> String {
        if let delta = snapshot.expenseDeltaPercentage {
            if delta >= 0 {
                return appLanguage.localized("dashboard.hero.expensesUp", appLanguage.formatPercent(abs(delta)))
            } else {
                return appLanguage.localized("dashboard.hero.expensesDown", appLanguage.formatPercent(abs(delta)))
            }
        }
        return appLanguage.localized("This is the first comparable monthly snapshot available.")
    }

    private func deltaCaption(_ snapshot: DashboardSnapshot) -> String {
        let amount = renderAmount(snapshot.expenseDeltaFromPreviousMonth)
        guard let delta = snapshot.expenseDeltaPercentage else {
            return appLanguage.localized("No previous-month comparison yet.")
        }

        let trend = delta >= 0 ? appLanguage.localized("Higher") : appLanguage.localized("Lower")
        let percentage = appLanguage.formatPercent(abs(delta))
        return appLanguage.localized("dashboard.hero.deltaCaption", trend, amount, percentage)
    }

    private func decimalValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private func renderAmount(_ value: Decimal) -> String {
        value.privacyFormatted(hidden: privacyStoredValue, language: appLanguage)
    }
}

private struct DashboardHeroPanel: View {
    let snapshot: DashboardSnapshot
    let renderAmount: (Decimal) -> String
    let heroSubtitle: (DashboardSnapshot) -> String
    let deltaCaption: (DashboardSnapshot) -> String
    let decimalValue: (Decimal) -> Double

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

                    Text(heroSubtitle(snapshot))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: AppLayoutMetrics.contentGap) {
                    supportChip(
                        title: LocalizedStringKey("Income"),
                        value: renderAmount(snapshot.totalIncome),
                        tint: AppColors.income
                    )
                    supportChip(
                        title: LocalizedStringKey("Expenses"),
                        value: renderAmount(snapshot.totalExpenses),
                        tint: AppColors.expense
                    )
                    supportChip(
                        title: LocalizedStringKey("Delta"),
                        value: deltaCaption(snapshot),
                        tint: snapshot.expenseDeltaFromPreviousMonth > 0 ? AppColors.warning : AppColors.neutral
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
                if snapshot.trend.isEmpty {
                    Text(LocalizedStringKey("Not enough monthly movement yet to draw a trend."))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Chart(snapshot.trend) { point in
                        AreaMark(
                            x: .value("Day", point.dayLabel),
                            y: .value("Net", decimalValue(point.net))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.neutral.opacity(0.28), AppColors.neutral.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Day", point.dayLabel),
                            y: .value("Net", decimalValue(point.net))
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(AppColors.neutral.gradient)
                    }
                    .frame(width: 320, height: 180)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                }
            }
            .frame(width: 320, alignment: .topLeading)
        }
        .contentCard(padding: AppLayoutMetrics.heroInset, radius: AppRadius.hero)
    }

    private func supportChip(title: LocalizedStringKey, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppLayoutMetrics.contentGap)
        .padding(.vertical, 12)
        .liquidGlassPill(padding: 0, material: AppMaterials.subtleGlass, tint: tint)
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

private struct DashboardKPIStrip: View {
    let snapshot: DashboardSnapshot
    let renderAmount: (Decimal) -> String
    let appLanguage: AppLanguage

    private let columns = [
        GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap),
        GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap),
        GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppLayoutMetrics.contentGap) {
            kpiCard(
                title: LocalizedStringKey("Savings Rate"),
                value: snapshot.savingsRate.formatted(.percent.precision(.fractionLength(0))),
                subtitle: LocalizedStringKey("Net over income this month"),
                icon: "arrow.down.to.line.compact",
                tint: snapshot.savingsRate >= 0 ? AppColors.income : AppColors.expense
            )
            kpiCard(
                title: LocalizedStringKey("Dominant Category"),
                value: snapshot.dominantCategoryName ?? appLanguage.localized("No category yet"),
                subtitle: LocalizedStringKey("Main pressure point of the month"),
                icon: "chart.bar.fill",
                tint: AppColors.warning
            )
            kpiCard(
                title: LocalizedStringKey("Pending Review"),
                value: "\(snapshot.pendingReviewCount)",
                subtitle: snapshot.pendingReviewCount == 0 ? LocalizedStringKey("Month is mostly settled") : LocalizedStringKey("Movements still affecting certainty"),
                icon: "exclamationmark.bubble.fill",
                tint: snapshot.pendingReviewCount == 0 ? AppColors.neutral : AppColors.warning
            )
        }
    }

    private func kpiCard(title: LocalizedStringKey, value: String, subtitle: LocalizedStringKey, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 24, height: 24)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(2)
                .contentTransition(.numericText())

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }
}

private struct DashboardCopilotCard: View {
    let summary: String?
    let alerts: [String]
    let actions: [String]
    let isLoading: Bool
    let openInsights: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            HStack(alignment: .center) {
                Label(LocalizedStringKey("AI Copilot"), systemImage: "sparkles")
                    .font(AppTypography.sectionTitle)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(LocalizedStringKey("Open Analysis"), action: openInsights)
                        .appSecondaryGlassButton()
                }
            }

            Text(LocalizedStringKey(summary ?? "No AI summary available yet."))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(4)

            HStack(alignment: .top, spacing: AppLayoutMetrics.contentGap) {
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

private struct DashboardCategoryPressureCard: View {
    let snapshot: DashboardSnapshot
    let chartPalette: [Color]
    let renderAmount: (Decimal) -> String
    let decimalValue: (Decimal) -> Double

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            Label(LocalizedStringKey("Top Categories"), systemImage: "chart.bar.doc.horizontal")
                .font(AppTypography.sectionTitle)

            if snapshot.topCategories.isEmpty {
                Text(LocalizedStringKey("No categorized expenses yet this month."))
                    .foregroundStyle(.secondary)
            } else {
                Chart(Array(snapshot.topCategories.enumerated()), id: \.element.id) { index, item in
                    BarMark(
                        x: .value("Amount", decimalValue(item.amount)),
                        y: .value("Category", item.name)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .foregroundStyle(chartPalette[index % chartPalette.count].gradient)
                }
                .frame(height: 180)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }

                ForEach(Array(snapshot.topCategories.enumerated()), id: \.element.id) { index, item in
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
        .contentCard()
    }
}

private struct DashboardRecentImportsCard: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    let snapshot: DashboardSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            Label(LocalizedStringKey("Recent Imports"), systemImage: "square.and.arrow.down.on.square")
                .font(AppTypography.sectionTitle)

            if snapshot.recentImports.isEmpty {
                Text(LocalizedStringKey("No imports yet. Start by loading a CSV, XLSX or PDF export."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.recentImports) { session in
                    VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                        HStack {
                            Text(session.fileName)
                                .lineLimit(1)
                            Spacer()
                            Text(appLanguage.localized("recentImports.rows", appLanguage.formatInteger(session.importedRowCount)))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text(appLanguage.format(date: session.importedAt, dateStyle: .medium, timeStyle: .short))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, AppLayoutMetrics.microGap)
                }
            }
        }
        .contentCard()
    }
}

private struct DashboardConfidenceCard: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    let snapshot: DashboardSnapshot
    let renderAmount: (Decimal) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            Label(LocalizedStringKey("Month Confidence"), systemImage: "gauge.with.dots.needle.50percent")
                .font(AppTypography.sectionTitle)

            Text(appLanguage.localized("dashboard.confidence.pendingReview", appLanguage.formatInteger(snapshot.pendingReviewCount), snapshot.monthTitle))
                .foregroundStyle(.secondary)

            ProgressView(value: snapshot.categorizedPercentage)
                .tint(snapshot.categorizedPercentage >= 0.85 ? AppColors.income : AppColors.warning)

            Text(appLanguage.localized("dashboard.confidence.coverage", appLanguage.formatPercent(snapshot.categorizedPercentage)))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if snapshot.uncategorizedExpenseCount > 0 {
                Text(
                    appLanguage.localized(
                        "dashboard.confidence.uncategorized",
                        appLanguage.formatInteger(snapshot.uncategorizedExpenseCount),
                        renderAmount(snapshot.uncategorizedExpenseAmount)
                    )
                )
                .font(.footnote)
                .foregroundStyle(AppColors.warning)
            }
        }
        .contentCard()
    }
}
