import Charts
import SwiftUI

struct MacInsightsView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled = false
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .english
    @State private var viewModel = InsightsViewModel()
    @State private var selectedHeroCategory: String?
    @State private var selectedCategory: String?
    @State private var selectedMonthlyLabel: String?
    @State private var selectedEvolutionDate: Date?
    @State private var selectedEvolutionCategory: String?

    private let chartPalette: [Color] = [
        Color(hue: 0.60, saturation: 0.70, brightness: 0.92),
        Color(hue: 0.44, saturation: 0.65, brightness: 0.82),
        Color(hue: 0.10, saturation: 0.75, brightness: 0.96),
        Color(hue: 0.97, saturation: 0.60, brightness: 0.88),
        Color(hue: 0.72, saturation: 0.55, brightness: 0.90),
        Color(hue: 0.53, saturation: 0.60, brightness: 0.80)
    ]

    var body: some View {
        GlassPageScaffold {
            header
        } content: {
            VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                if let snapshot = viewModel.snapshot {
                    heroSection(snapshot)
                    if let planningSnapshot = viewModel.planningSnapshot {
                        FinancialBalanceProjectionCard(
                            snapshot: planningSnapshot,
                            renderAmount: { renderAmount($0) },
                            appLanguage: appLanguage
                        )
                    }
                    insightsContentGrid(snapshot)
                } else if viewModel.isLoading {
                    LoadingView(title: LocalizedStringKey("Analyzing finances..."))
                        .liquidGlassPanel(
                            padding: AppLayoutMetrics.heroInset,
                            radius: AppRadius.panelGroup,
                            material: AppMaterials.groupedGlass,
                            tint: AppColors.neutral
                        )
                } else {
                    EmptyStateView(
                        title: LocalizedStringKey("No Financial Analysis Yet"),
                        message: LocalizedStringKey("Import real bank movements to unlock cashflow charts, category trends and forward-looking forecasts."),
                        systemImage: "chart.xyaxis.line"
                    )
                    .liquidGlassPanel(
                        padding: AppLayoutMetrics.heroInset,
                        radius: AppRadius.panelGroup,
                        material: AppMaterials.groupedGlass,
                        tint: AppColors.neutral
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(AppColors.expense)
                        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.card)
                }
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
        .navigationTitle(LocalizedStringKey("Analysis"))
    }

    private func insightsContentGrid(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        HStack(alignment: .top, spacing: AppLayoutMetrics.sectionGap) {
            VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                overviewBand(snapshot)

                primaryAnalyticsColumn(snapshot)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                aiNarrativeSection
                secondaryAnalyticsColumn(snapshot)
            }
            .frame(width: 360, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppLayoutMetrics.sectionGap) {
            VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
                Text(LocalizedStringKey("Financial Explorer"))
                    .font(AppTypography.displayTitle)
                Text(LocalizedStringKey("A visual overview of household cashflow, category pressure, recurring charges and medium-term projection."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 720, alignment: .leading)
            }

            Spacer(minLength: AppLayoutMetrics.contentGap)

            HStack(spacing: AppLayoutMetrics.contentGap) {
                rangePicker

                Button {
                    isPrivacyModeEnabled.toggle()
                } label: {
                    Label(
                        isPrivacyModeEnabled ? LocalizedStringKey("Privacy On") : LocalizedStringKey("Privacy Off"),
                        systemImage: isPrivacyModeEnabled ? "eye.slash.fill" : "eye.fill"
                    )
                }
                .appSecondaryGlassButton()
                .controlSize(.small)
                .help(isPrivacyModeEnabled ? LocalizedStringKey("Show amounts") : LocalizedStringKey("Hide amounts"))
            }
        }
    }

    private var rangePicker: some View {
        Picker(
            "",
            selection: Binding(
                get: { viewModel.selectedRange },
                set: { newValue in
                    Task {
                        await viewModel.refreshRange(newValue, using: appContainer, language: appLanguage)
                    }
                }
            )
        ) {
            ForEach(AnalysisTimeRange.allCases) { range in
                Text(appLanguage.localized(range.title))
                    .tag(range)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 300)
    }

    private func heroSection(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        LiquidGlassContainer(spacing: AppLayoutMetrics.glassMergeSpacing) {
            HStack(alignment: .top, spacing: AppLayoutMetrics.sectionGap) {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
                    HStack(spacing: 12) {
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 42, height: 42)
                            .liquidGlassPill(padding: 0, tint: AppColors.neutral)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Net household position"))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(LocalizedStringKey("Actual result for the selected period."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(renderAmount(snapshot.netBalance))
                            .font(AppTypography.heroNumber)
                            .foregroundStyle(snapshot.netBalance >= 0 ? AppColors.income : AppColors.expense)
                            .contentTransition(.numericText())

                        Text(snapshot.forecast.isNegativeTrend ? LocalizedStringKey("Spending pressure is starting to outweigh incoming cashflow.") : LocalizedStringKey("Cashflow remains resilient over the selected period."))
                            .font(.headline)
                            .foregroundStyle(.primary.opacity(0.84))

                        Label(netTrendTitle(for: snapshot), systemImage: netTrendIcon(for: snapshot))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(netTrendColor(for: snapshot))

                        if let netDelta = snapshot.netDeltaFromPreviousMonth {
                            Text(appLanguage.localized("Net change: %@", renderAmount(netDelta)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: AppLayoutMetrics.microGap) {
                        statusChip(
                            title: LocalizedStringKey("Income"),
                            value: renderAmount(snapshot.totalIncome),
                            color: AppColors.income
                        )
                        statusChip(
                            title: LocalizedStringKey("Expenses"),
                            value: renderAmount(snapshot.totalExpenses),
                            color: AppColors.expense
                        )
                        statusChip(
                            title: LocalizedStringKey("Review"),
                            value: appLanguage.localized("insights.pendingCount", appLanguage.formatInteger(snapshot.pendingReviewCount)),
                            color: snapshot.pendingReviewCount == 0 ? AppColors.neutral : AppColors.warning
                        )
                        statusChip(
                            title: LocalizedStringKey("Expense coverage"),
                            value: appLanguage.formatPercent(snapshot.dataQuality.expenseCategorizationCoverage),
                            color: snapshot.dataQuality.isReliable ? AppColors.income : AppColors.warning
                        )
                    }

                    Text(appLanguage.localized(
                        "insights.scopeSummary",
                        scopeTitle(for: snapshot.range),
                        appLanguage.formatInteger(snapshot.pendingReviewCount)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if snapshot.dataQuality.internalTransferCount > 0 {
                        Text(appLanguage.localized(
                            "insights.transferExclusion",
                            appLanguage.formatInteger(snapshot.dataQuality.internalTransferCount)
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
                    sectionHeader(
                        title: LocalizedStringKey("Category concentration"),
                        icon: "chart.bar.fill",
                        tint: AppColors.neutral
                    )

                    if snapshot.categoryBreakdown.isEmpty {
                        Text(LocalizedStringKey("Import categorized data to visualize where the money is going."))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Chart {
                            ForEach(Array(snapshot.categoryBreakdown.prefix(5)).enumerated(), id: \.element.id) { index, item in
                                BarMark(
                                    x: .value("Amount", decimalValue(item.amount)),
                                    y: .value("Category", item.categoryName)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .foregroundStyle(chartPalette[index % chartPalette.count].gradient)
                                .opacity(selectedHeroCategory == nil || selectedHeroCategory == item.categoryName ? 1.0 : 0.35)
                            }

                            if let selectedHeroCategory {
                                RuleMark(y: .value("Category", selectedHeroCategory))
                                    .foregroundStyle(AppColors.neutral.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            }
                        }
                        .frame(height: 180)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(.clear)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                updateHeroSelection(at: value.location, proxy: proxy, geometry: geometry)
                                            }
                                            .onEnded { value in
                                                updateHeroSelection(at: value.location, proxy: proxy, geometry: geometry)
                                            }
                                    )
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if let selectedHeroCategory,
                               let selectedItem = snapshot.categoryBreakdown.first(where: { $0.categoryName == selectedHeroCategory }) {
                                InChartCalloutOverlay(
                                    title: selectedItem.categoryName,
                                    items: [
                                        InChartCalloutOverlayItem(label: appLanguage.localized("Expenses"), value: renderAmount(selectedItem.amount), color: AppColors.expense),
                                        InChartCalloutOverlayItem(label: appLanguage.localized("Share"), value: appLanguage.formatPercent(selectedItem.percentage), color: AppColors.income)
                                    ],
                                    alignment: .topTrailing
                                )
                            }
                        }
                    }
                }
                .frame(width: 360)
                .liquidGlassPanel(
                    padding: AppLayoutMetrics.contentGap,
                    radius: AppRadius.card,
                    material: AppMaterials.subtleGlass,
                    tint: AppColors.neutral,
                    shadowRadius: 14,
                    shadowY: 8,
                    shadowOpacity: 0.10
                )
            }
            .liquidGlassHero(tint: snapshot.netBalance >= 0 ? AppColors.income : AppColors.expense)
        }
    }

    private func overviewBand(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            sectionHeader(
                title: LocalizedStringKey("Signal deck"),
                icon: "rectangle.grid.2x2.fill",
                tint: AppColors.neutral
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap),
                    GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap),
                    GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap),
                    GridItem(.flexible(), spacing: AppLayoutMetrics.contentGap)
                ],
                spacing: AppLayoutMetrics.contentGap
            ) {
                metricCard(
                    title: LocalizedStringKey("Categorized"),
                    value: appLanguage.formatPercent(snapshot.categorizedPercentage),
                    subtitle: LocalizedStringKey("Coverage of the imported base"),
                    icon: "checkmark.seal.fill",
                    tint: AppColors.neutral
                )
                metricCard(
                    title: LocalizedStringKey("Savings Rate"),
                    value: appLanguage.formatPercent(snapshot.savingsRate),
                    subtitle: LocalizedStringKey("Net over income"),
                    icon: "arrow.down.to.line.compact",
                    tint: AppColors.income
                )
                metricCard(
                    title: LocalizedStringKey("Recurring Charges"),
                    value: appLanguage.formatInteger(snapshot.recurringExpenses.count),
                    subtitle: LocalizedStringKey("Patterns detected"),
                    icon: "repeat.circle.fill",
                    tint: AppColors.warning
                )
                metricCard(
                    title: LocalizedStringKey("Forecast 12M"),
                    value: renderAmount(snapshot.forecast.projectedDelta12Months),
                    subtitle: LocalizedStringKey("Deterministic projection"),
                    icon: "sparkline",
                    tint: snapshot.forecast.projectedDelta12Months >= 0 ? AppColors.income : AppColors.expense
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private var aiNarrativeSection: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            sectionHeader(
                title: LocalizedStringKey("AI Copilot Summary"),
                icon: "sparkles.rectangle.stack.fill",
                tint: AppColors.warning
            )

            if viewModel.isGeneratingNarrative {
                HStack(spacing: AppLayoutMetrics.contentGap) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LocalizedStringKey("Generating summary..."))
                        .foregroundStyle(.secondary)
                }
                .liquidGlassPill(padding: 14, tint: AppColors.warning)
            } else {
                AnalysisNarrativeView(narrative: viewModel.aiNarrative)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private func primaryAnalyticsColumn(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            monthlyTrendSection(snapshot)
            sectionSeparator
            categorySection(snapshot)
            sectionSeparator
            categoryEvolutionSection(snapshot)
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private func secondaryAnalyticsColumn(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            forecastSection(snapshot)
            sectionSeparator
            recurringSection(snapshot)
            sectionSeparator
            reviewImpactSection(snapshot)
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private var sectionSeparator: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.24),
                        Color.white.opacity(0.04)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }

    private func categorySection(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        let allCategories = snapshot.categoryBreakdown.map(\.categoryName)

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            sectionHeader(
                title: LocalizedStringKey("Expenses by Category"),
                icon: "chart.bar.doc.horizontal",
                tint: AppColors.expense
            )

            if snapshot.categoryBreakdown.isEmpty {
                Text(LocalizedStringKey("No category data available yet."))
                    .foregroundStyle(.secondary)
            } else {
                CategoryChartFilterControl(
                    availableCategories: allCategories,
                    selectedCategory: $selectedCategory,
                    appLanguage: appLanguage
                )

                let displayedBreakdown = selectedCategory != nil
                    ? snapshot.categoryBreakdown.filter { $0.categoryName == selectedCategory }
                    : Array(snapshot.categoryBreakdown.prefix(8))

                Chart {
                    ForEach(Array(displayedBreakdown.enumerated()), id: \.element.id) { index, item in
                        BarMark(
                            x: .value("Category", item.categoryName),
                            y: .value("Amount", decimalValue(item.amount))
                        )
                        .foregroundStyle(chartPalette[index % chartPalette.count].gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }

                    if let selectedCategory {
                        RuleMark(x: .value("Category", selectedCategory))
                            .foregroundStyle(AppColors.neutral.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(.clear)
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateCategorySelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        updateCategorySelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let selectedCategory,
                       let selectedItem = snapshot.categoryBreakdown.first(where: { $0.categoryName == selectedCategory }) {
                        InChartCalloutOverlay(
                            title: selectedItem.categoryName,
                            items: [
                                InChartCalloutOverlayItem(label: appLanguage.localized("Expenses"), value: renderAmount(selectedItem.amount), color: AppColors.expense),
                                InChartCalloutOverlayItem(label: appLanguage.localized("Share"), value: appLanguage.formatPercent(selectedItem.percentage), color: AppColors.income),
                                InChartCalloutOverlayItem(label: appLanguage.localized("Change"), value: deltaLabel(for: selectedItem.deltaFromPreviousPeriod), color: AppColors.neutral)
                            ],
                            alignment: .topTrailing
                        )
                    }
                }

                ForEach(Array(snapshot.categoryBreakdown.prefix(6)).enumerated(), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        HStack {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(chartPalette[index % chartPalette.count])
                                    .frame(width: 10, height: 10)
                                Text(item.categoryName)
                                    .font(.headline)
                            }
                            Spacer()
                            Text(renderAmount(item.amount))
                                .font(.headline)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                Capsule()
                                    .fill(chartPalette[index % chartPalette.count].gradient)
                                    .frame(width: max(12, proxy.size.width * min(max(item.percentage, 0.02), 1)))
                            }
                        }
                        .frame(height: 10)

                        HStack {
                            Text(item.percentage.formatted(.percent.precision(.fractionLength(0))))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(deltaLabel(for: item.deltaFromPreviousPeriod))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.deltaFromPreviousPeriod >= 0 ? AppColors.warning : AppColors.income)
                        }
                    }
                    .padding(.top, AppSpacing.xSmall)
                }
            }
        }
    }

    private func categoryEvolutionSection(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        let allEvolutionCategories = snapshot.categoryEvolution.map(\.categoryName)
        let items: [CategoryEvolutionItem] = {
            if let selectedEvolutionCategory {
                return snapshot.categoryEvolution.filter { $0.categoryName == selectedEvolutionCategory }
            } else {
                return Array(snapshot.categoryEvolution.prefix(5))
            }
        }()
        let points = items.flatMap(\.points)

        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            sectionHeader(
                title: LocalizedStringKey("Category evolution"),
                icon: "chart.line.uptrend.xyaxis",
                tint: AppColors.warning
            )

            Text(LocalizedStringKey("Compare the latest months and spot categories whose spending is accelerating."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if snapshot.categoryEvolution.isEmpty {
                Text(LocalizedStringKey("No category evolution available yet."))
                    .foregroundStyle(.secondary)
            } else {
                CategoryChartFilterControl(
                    availableCategories: allEvolutionCategories,
                    selectedCategory: $selectedEvolutionCategory,
                    appLanguage: appLanguage
                )

                Chart(points) { point in
                    if selectedEvolutionCategory != nil {
                        AreaMark(
                            x: .value("Month", point.startDate),
                            y: .value("Amount", decimalValue(point.amount))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppColors.income.opacity(0.18).gradient)
                    }

                    LineMark(
                        x: .value("Month", point.startDate),
                        y: .value("Amount", decimalValue(point.amount))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Category", point.categoryName))

                    PointMark(
                        x: .value("Month", point.startDate),
                        y: .value("Amount", decimalValue(point.amount))
                    )
                    .foregroundStyle(by: .value("Category", point.categoryName))

                    if let selectedEvolutionDate {
                        RuleMark(x: .value("Month", selectedEvolutionDate))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    }
                }
                .frame(height: 250)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateEvolutionDateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        updateEvolutionDateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let selectedEvolutionDate,
                       let nearestDate = points.min(by: {
                           abs($0.startDate.timeIntervalSince(selectedEvolutionDate)) < abs($1.startDate.timeIntervalSince(selectedEvolutionDate))
                       })?.startDate {
                        let overlayItems: [InChartCalloutOverlayItem] = items.map { item in
                            let point = item.points.first { $0.startDate == nearestDate }
                            return InChartCalloutOverlayItem(
                                label: item.categoryName,
                                value: renderAmount(point?.amount ?? .zero),
                                color: nil
                            )
                        }

                        InChartCalloutOverlay(
                            title: nearestDate.formatted(.dateTime.month(.wide).year()),
                            items: overlayItems,
                            alignment: .topLeading
                        )
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    ForEach(snapshot.categoryEvolution.filter(\.isSpiking).prefix(6)) { item in
                        HStack(alignment: .top, spacing: AppSpacing.small) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .foregroundStyle(AppColors.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.categoryName)
                                    .font(.subheadline.weight(.semibold))
                                Text(spikeCaption(for: item))
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
    }

    private func monthlyTrendSection(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            sectionHeader(
                title: LocalizedStringKey("Monthly Cashflow"),
                icon: "waveform.path.ecg.rectangle",
                tint: AppColors.neutral
            )

            if snapshot.monthlyCashflow.isEmpty {
                Text(LocalizedStringKey("Not enough monthly history to visualize cashflow."))
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(snapshot.monthlyCashflow) { point in
                        BarMark(
                            x: .value("Month", point.monthLabel),
                            y: .value("Expenses", decimalValue(point.expense) * -1)
                        )
                        .foregroundStyle(AppColors.expense.opacity(0.32).gradient)

                        BarMark(
                            x: .value("Month", point.monthLabel),
                            y: .value("Income", decimalValue(point.income))
                        )
                        .foregroundStyle(AppColors.income.opacity(0.40).gradient)

                        LineMark(
                            x: .value("Month", point.monthLabel),
                            y: .value("Net", decimalValue(point.net))
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(AppColors.neutral.gradient)

                        AreaMark(
                            x: .value("Month", point.monthLabel),
                            y: .value("Net", decimalValue(point.net))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.neutral.opacity(0.24), AppColors.neutral.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    if let selectedMonthlyLabel {
                        RuleMark(x: .value("Month", selectedMonthlyLabel))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    }
                }
                .frame(height: 280)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateMonthlySelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        updateMonthlySelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let selectedMonthlyLabel,
                       let selectedPoint = snapshot.monthlyCashflow.first(where: { $0.monthLabel == selectedMonthlyLabel }) {
                        InChartCalloutOverlay(
                            title: selectedPoint.monthLabel,
                            items: [
                                InChartCalloutOverlayItem(label: appLanguage.localized("Income"), value: renderAmount(selectedPoint.income), color: AppColors.income),
                                InChartCalloutOverlayItem(label: appLanguage.localized("Expenses"), value: renderAmount(selectedPoint.expense), color: AppColors.expense),
                                InChartCalloutOverlayItem(label: appLanguage.localized("Net"), value: renderAmount(selectedPoint.net), color: selectedPoint.net >= 0 ? AppColors.neutral : AppColors.warning)
                            ],
                            alignment: .topLeading
                        )
                    }
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.small),
                    GridItem(.flexible(), spacing: AppSpacing.small),
                    GridItem(.flexible(), spacing: AppSpacing.small)
                ],
                spacing: AppSpacing.small
            ) {
                summaryBadge(
                    title: LocalizedStringKey("Best month"),
                    value: bestMonth(in: snapshot.monthlyCashflow) ?? String(localized: "N/A"),
                    tint: AppColors.income
                )
                summaryBadge(
                    title: LocalizedStringKey("Worst month"),
                    value: worstMonth(in: snapshot.monthlyCashflow) ?? String(localized: "N/A"),
                    tint: AppColors.expense
                )
                summaryBadge(
                    title: LocalizedStringKey("Avg. monthly net"),
                    value: renderAmount(snapshot.forecast.averageMonthlyNet),
                    tint: AppColors.neutral
                )
            }
        }
    }

    private func forecastSection(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            sectionHeader(
                title: LocalizedStringKey("Forecast"),
                icon: "binoculars.fill",
                tint: AppColors.neutral
            )

            Text(appLanguage.localized(
                "forecast.basedOnMonths",
                appLanguage.formatInteger(snapshot.forecast.sourceMonthCount)
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: AppSpacing.small) {
                projectionCard(title: "3M", value: snapshot.forecast.projectedDelta3Months, tint: .teal)
                projectionCard(title: "6M", value: snapshot.forecast.projectedDelta6Months, tint: AppColors.neutral)
                projectionCard(title: "12M", value: snapshot.forecast.projectedDelta12Months, tint: snapshot.forecast.projectedDelta12Months >= 0 ? AppColors.income : AppColors.expense)
            }

            Text(snapshot.forecast.hasLimitedHistory
                ? LocalizedStringKey("forecast.limitedHistory")
                : (snapshot.forecast.isNegativeTrend
                    ? LocalizedStringKey("Warning: current pace could deteriorate household liquidity over the coming months.")
                    : LocalizedStringKey("Current pace remains resilient over the medium term.")))
                .font(.footnote)
                .foregroundStyle(snapshot.forecast.hasLimitedHistory || snapshot.forecast.isNegativeTrend ? AppColors.warning : .secondary)
        }
    }

    private func recurringSection(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            sectionHeader(
                title: LocalizedStringKey("Recurring Expenses"),
                icon: "repeat",
                tint: AppColors.warning
            )

            HStack(alignment: .top, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Recurring monthly total"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(renderAmount(snapshot.recurringMonthlyExpenses))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.warning)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(LocalizedStringKey("Confirmed monthly expenses"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appLanguage.formatInteger(confirmedRecurringCount(in: snapshot)))
                        .font(.title3.weight(.bold))
                }
            }
            .padding(AppSpacing.medium)
            .liquidGlassPanel(
                padding: 0,
                radius: AppRadius.card,
                material: AppMaterials.subtleGlass,
                tint: AppColors.warning,
                shadowRadius: 8,
                shadowY: 4,
                shadowOpacity: 0.06
            )

            Text(LocalizedStringKey("Detected recurring expenses are calculated from the full eligible history."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if snapshot.recurringExpenses.isEmpty {
                Text(LocalizedStringKey("No recurring expenses detected yet."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.recurringExpenses.prefix(6)) { item in
                    recurringExpenseRow(item)
                }
            }
        }
    }

    private func recurringExpenseRow(_ item: RecurringExpenseItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(recurringStatusColor(item.status))
                    .frame(width: 38, height: 38)
                    .liquidGlassPill(padding: 0, tint: recurringStatusColor(item.status))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.merchantName ?? item.concept)
                        .lineLimit(1)
                    Text(appLanguage.localized(
                        "recurring.coverage",
                        appLanguage.formatInteger(item.occurrences),
                        appLanguage.formatInteger(item.expectedMonths)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(renderAmount(item.averageAmount))
                        .font(.headline)
                    Text(LocalizedStringKey("per month"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: AppSpacing.small) {
                Text(recurringStatusTitle(for: item.status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(recurringStatusColor(item.status))

                if let categoryName = item.categoryName {
                    Text(appLanguage.localized("recurring.category", categoryName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(appLanguage.localized("recurring.lastCharge", appLanguage.format(date: item.latestDate, dateStyle: .medium)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !item.missingMonths.isEmpty {
                Text(appLanguage.localized("recurring.missingMonths", appLanguage.formatInteger(item.missingMonths.count)))
                    .font(.caption2)
                    .foregroundStyle(AppColors.warning)
            }
        }
        .padding(.vertical, AppSpacing.small)
        .padding(.horizontal, AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(recurringStatusColor(item.status).opacity(0.08))
        )
    }

    private func confirmedRecurringCount(in snapshot: FinancialAnalysisSnapshot) -> Int {
        snapshot.recurringExpenses.filter { $0.status == .confirmed }.count
    }

    private func recurringStatusTitle(for status: RecurringExpenseDetectionStatus) -> LocalizedStringKey {
        switch status {
        case .confirmed: return "Recurring pattern confirmed"
        case .provisional: return "Recurring pattern provisional"
        }
    }

    private func recurringStatusColor(_ status: RecurringExpenseDetectionStatus) -> Color {
        status == .confirmed ? AppColors.warning : AppColors.neutral
    }

    private func reviewImpactSection(_ snapshot: FinancialAnalysisSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            sectionHeader(
                title: LocalizedStringKey("Review Impact"),
                icon: "exclamationmark.bubble.fill",
                tint: AppColors.warning
            )

            Text(appLanguage.localized(
                "insights.reviewImpact",
                appLanguage.formatInteger(snapshot.pendingReviewCount),
                scopeTitle(for: snapshot.range)
            ))
                .foregroundStyle(.secondary)

        }
    }

    private func sectionHeader(title: LocalizedStringKey, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .liquidGlassPill(padding: 0, tint: tint)

            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(.primary)
        }
    }

    private func metricCard(title: LocalizedStringKey, value: String, subtitle: LocalizedStringKey, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .liquidGlassPill(padding: 0, tint: tint)
                Spacer()
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .contentTransition(.numericText())
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassPanel(
            padding: AppLayoutMetrics.contentGap,
            radius: AppRadius.card,
            material: AppMaterials.subtleGlass,
            tint: tint,
            shadowRadius: 10,
            shadowY: 6,
            shadowOpacity: 0.08
        )
    }

    private func projectionCard(title: String, value: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(renderAmount(value))
                .font(.title3.weight(.bold))
                .foregroundStyle(value >= 0 ? tint : AppColors.expense)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassPanel(
            padding: AppSpacing.medium,
            radius: AppRadius.card,
            material: AppMaterials.subtleGlass,
            tint: tint,
            shadowRadius: 10,
            shadowY: 6,
            shadowOpacity: 0.08
        )
    }

    private func summaryBadge(title: LocalizedStringKey, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassPanel(
            padding: AppSpacing.small,
            radius: AppRadius.card,
            material: AppMaterials.subtleGlass,
            tint: tint,
            shadowRadius: 8,
            shadowY: 4,
            shadowOpacity: 0.06
        )
    }

    private func netTrendTitle(for snapshot: FinancialAnalysisSnapshot) -> LocalizedStringKey {
        switch snapshot.netTrend {
        case .increasing: return "Net trend increasing"
        case .decreasing: return "Net trend decreasing"
        case .stable: return "Net trend stable"
        case .insufficientData: return "Not enough data for net trend"
        }
    }

    private func scopeTitle(for range: AnalysisTimeRange) -> String {
        switch range {
        case .month: return appLanguage.localized("1M")
        case .threeMonths: return appLanguage.localized("3M")
        case .sixMonths: return appLanguage.localized("6M")
        case .year: return appLanguage.localized("12M")
        case .all: return appLanguage.localized("All")
        }
    }

    private func netTrendIcon(for snapshot: FinancialAnalysisSnapshot) -> String {
        switch snapshot.netTrend {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "equal"
        case .insufficientData: return "questionmark"
        }
    }

    private func netTrendColor(for snapshot: FinancialAnalysisSnapshot) -> Color {
        switch snapshot.netTrend {
        case .increasing: return AppColors.income
        case .decreasing: return AppColors.warning
        case .stable, .insufficientData: return AppColors.neutral
        }
    }

    private func statusChip(title: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
        }
        .liquidGlassPill(padding: 14, tint: color)
    }

    private func renderAmount(_ value: Decimal, currencyCode: String = "EUR") -> String {
        value.privacyFormatted(hidden: isPrivacyModeEnabled, language: appLanguage, currencyCode: currencyCode)
    }

    private func deltaLabel(for value: Decimal) -> String {
        let formatted = renderAmount(value)
        return value >= 0 ? "+\(formatted)" : formatted
    }

    private func spikeCaption(for item: CategoryEvolutionItem) -> String {
        if let deltaPercentage = item.deltaPercentage {
            return appLanguage.localized("Category increased by %@", appLanguage.formatPercent(deltaPercentage))
        }
        return appLanguage.localized("Category appeared this month")
    }

    private func updateHeroSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        let yPosition = location.y - plotFrame.origin.y
        guard yPosition >= 0, yPosition <= plotFrame.size.height,
              let category: String = proxy.value(atY: yPosition, as: String.self) else { return }
        selectedHeroCategory = category
    }

    private func updateCategorySelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        let xPosition = location.x - plotFrame.origin.x
        guard xPosition >= 0, xPosition <= plotFrame.size.width,
              let category: String = proxy.value(atX: xPosition, as: String.self) else { return }
        selectedCategory = category
    }

    private func updateEvolutionDateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        let xPosition = location.x - plotFrame.origin.x
        guard xPosition >= 0, xPosition <= plotFrame.size.width,
              let date: Date = proxy.value(atX: xPosition, as: Date.self) else { return }
        selectedEvolutionDate = date
    }

    private func updateMonthlySelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        let xPosition = location.x - plotFrame.origin.x
        guard xPosition >= 0, xPosition <= plotFrame.size.width,
              let label: String = proxy.value(atX: xPosition, as: String.self) else { return }
        selectedMonthlyLabel = label
    }

    private func bestMonth(in points: [MonthlyCashflowPoint]) -> String? {
        points.max(by: { $0.net < $1.net })?.monthLabel
    }

    private func worstMonth(in points: [MonthlyCashflowPoint]) -> String? {
        points.min(by: { $0.net < $1.net })?.monthLabel
    }

    private func decimalValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

struct AnalysisNarrativeView: View {
    let narrative: String?
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english

    init(narrative: String?) {
        self.narrative = narrative
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            if let narrative, !narrative.isEmpty {
                let lines = parseNarrative(narrative)
                ForEach(lines, id: \.title) { item in
                    NarrativeItemView(item: item)
                }
            } else {
                Text(appLanguage.localized("No AI summary available."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func parseNarrative(_ text: String) -> [NarrativePoint] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.cleanedNarrativeMarkdownLine() }
            .filter { !$0.isEmpty }

        return lines.compactMap { line -> NarrativePoint? in
            let sanitized = line.cleanedNarrativeMarkdownLine()
            let parts = sanitized.components(separatedBy: ":")

            if parts.count >= 2 {
                let title = parts[0].cleanedNarrativeMarkdownInline()
                let description = parts.dropFirst().joined(separator: ":").cleanedNarrativeMarkdownInline()
                return NarrativePoint(title: title, description: description)
            } else if !sanitized.isEmpty {
                return NarrativePoint(title: "", description: sanitized.cleanedNarrativeMarkdownInline())
            }
            return nil
        }
    }
}

private struct NarrativePoint {
    let title: String
    let description: String
}

private struct NarrativeItemView: View {
    let item: NarrativePoint

    var body: some View {
        HStack(alignment: .top, spacing: AppLayoutMetrics.contentGap) {
            Image(systemName: iconFor(item.title))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(colorFor(item.title))
                .frame(width: 34, height: 34)
                .liquidGlassPill(padding: 0, tint: colorFor(item.title))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                if !item.title.isEmpty {
                    Text(item.title)
                        .font(.headline)
                }
                Text(item.description.cleanedNarrativeMarkdownInline())
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func iconFor(_ title: String) -> String {
        let t = title.lowercased()
        if t.contains("situación") || t.contains("situation") || t.contains("actual") { return "chart.pie.fill" }
        if t.contains("tendencia") || t.contains("trend") { return "chart.line.uptrend.xyaxis" }
        if t.contains("riesgo") || t.contains("risk") { return "exclamationmark.triangle.fill" }
        if t.contains("prioridad") || t.contains("priority") || t.contains("revisión") || t.contains("review") { return "checklist" }
        if t.contains("ahorro") || t.contains("savings") { return "leaf.fill" }
        return "sparkles"
    }

    private func colorFor(_ title: String) -> Color {
        let t = title.lowercased()
        if t.contains("riesgo") || t.contains("risk") { return AppColors.warning }
        if t.contains("situación") || t.contains("actual") { return AppColors.neutral }
        if t.contains("tendencia") || t.contains("trend") { return .indigo }
        if t.contains("prioridad") || t.contains("revisión") { return .purple }
        return AppColors.accent
    }
}

private extension String {
    func removingPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }

    func cleanedNarrativeMarkdownLine() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"^\s*([*\-•]+|\d+[.)])\s*"#,
                with: "",
                options: .regularExpression
            )
            .cleanedNarrativeMarkdownInline()
    }

    func cleanedNarrativeMarkdownInline() -> String {
        replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(
                of: #"\s{2,}"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
