import Charts
import SwiftUI

struct MacCategoriesView: View {
    @Environment(\.appContainer) private var appContainer
    @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = CategoriesViewModel()
    @State private var transactionsViewModel = TransactionsViewModel()
    @State private var selectedCategory: CategoryListItem?
    @State private var selectedDetailRange: AnalysisTimeRange = .sixMonths
    @State private var selectedDetailDate: Date?

    private let chartPalette: [Color] = [
        Color(hue: 0.60, saturation: 0.70, brightness: 0.92),
        Color(hue: 0.44, saturation: 0.65, brightness: 0.82),
        Color(hue: 0.10, saturation: 0.75, brightness: 0.96),
        Color(hue: 0.97, saturation: 0.60, brightness: 0.88),
        Color(hue: 0.72, saturation: 0.55, brightness: 0.90),
        Color(hue: 0.53, saturation: 0.60, brightness: 0.80)
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: AppSpacing.medium)
    ]

    private var categoryCount: Int {
        viewModel.categories.count
    }

    private var transactionCount: Int {
        viewModel.categories.reduce(0) { $0 + $1.transactionCount }
    }

    private var systemCategoryCount: Int {
        viewModel.categories.filter(\.isSystem).count
    }

    private var incomeCategoryCount: Int {
        viewModel.categories.filter { $0.group == "Income" }.count
    }

    var body: some View {
        Group {
            if viewModel.categories.isEmpty {
                emptyState
            } else if let selectedCategory {
                detailView(for: selectedCategory)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        header

                        LazyVGrid(columns: columns, spacing: AppSpacing.medium) {
                            ForEach(viewModel.categories) { item in
                                CategoryCard(item: item) {
                                    openCategoryDetail(item)
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.large)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Categories"))
        .onAppear {
            reloadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            reloadData()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(LocalizedStringKey("Categories"))
                    .font(AppTypography.displayTitle)

                Text(LocalizedStringKey("categories.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 520, alignment: .leading)
            }

            HStack(alignment: .top, spacing: AppSpacing.small) {
                SummaryChip(value: appLanguage.formatInteger(categoryCount), label: "Categories")
                SummaryChip(value: appLanguage.formatInteger(transactionCount), label: "Movements")
                SummaryChip(value: appLanguage.formatInteger(systemCategoryCount), label: "System")
                SummaryChip(value: appLanguage.formatInteger(incomeCategoryCount), label: "Income")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .glassCard(material: AppMaterials.groupedGlass)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.large) {
            VStack(spacing: AppSpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppColors.neutral.opacity(0.10))

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AppColors.neutral.opacity(0.12), lineWidth: 1)

                    Image(systemName: "tag")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppColors.neutral)
                }
                .frame(width: 72, height: 72)

                VStack(spacing: AppSpacing.small) {
                        Text(LocalizedStringKey("categories.empty.title"))
                        .font(.title3.weight(.semibold))

                    Text(LocalizedStringKey("categories.empty.message"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.large)
            .glassCard(material: AppMaterials.groupedGlass)

            HStack(spacing: AppSpacing.small) {
                SummaryChip(value: "0", label: "Categories")
                SummaryChip(value: "0", label: "Movements")
                SummaryChip(value: "0", label: "System")
                SummaryChip(value: "0", label: "Income")
            }
            .frame(maxWidth: 720)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.large)
    }

    private func detailView(for category: CategoryListItem) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                detailHeader(for: category)
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.top, AppSpacing.large)
                    .padding(.bottom, AppSpacing.medium)

                detailSpendTrendSection(for: category)
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.bottom, AppSpacing.medium)

                Divider()

                if transactionsViewModel.sortedTransactions.isEmpty {
                    categoryEmptyState(for: category)
                } else {
                    HSplitView {
                        TransactionTable(
                            transactions: transactionsViewModel.sortedTransactions,
                            searchText: $transactionsViewModel.searchText,
                            selectedTransaction: transactionsViewModel.selectedTransaction,
                            onSelect: { transaction in
                                transactionsViewModel.select(transaction)
                            }
                        )

                        TransactionInspectorView(
                            transaction: transactionsViewModel.selectedTransaction,
                            categories: transactionsViewModel.categories,
                            selectedCategoryID: transactionsViewModel.selectedCategoryID,
                            selectedKind: transactionsViewModel.selectedKind,
                            newCategoryName: transactionsViewModel.newCategoryName,
                            newCategoryIsIncome: transactionsViewModel.newCategoryIsIncome,
                            batchRecategorizationKind: transactionsViewModel.batchRecategorizationKind,
                            isRecategorizing: transactionsViewModel.isRecategorizing,
                            recategorizationSummary: transactionsViewModel.recategorizationSummary,
                            statusMessage: transactionsViewModel.statusMessage,
                            errorMessage: transactionsViewModel.errorMessage,
                            onSelectCategory: { categoryID in
                                transactionsViewModel.setSelectedCategory(categoryID)
                            },
                            onApplyCategory: { createRule in
                                transactionsViewModel.applyCategoryEdit(using: appContainer, createRule: createRule)
                            },
                            onSelectKind: { kind in
                                transactionsViewModel.selectedKind = kind
                            },
                            onApplyKind: {
                                transactionsViewModel.applyKindEdit(using: appContainer)
                            },
                            onNewCategoryNameChange: { name in
                                transactionsViewModel.newCategoryName = name
                            },
                            onNewCategoryIncomeChange: { isIncome in
                                transactionsViewModel.newCategoryIsIncome = isIncome
                            },
                            onCreateCategory: {
                                transactionsViewModel.createCategory(using: appContainer)
                            },
                            onBatchKindChange: { kind in
                                transactionsViewModel.batchRecategorizationKind = kind
                            },
                            onRecategorizeSelectedType: {
                                Task {
                                    await transactionsViewModel.recategorizeSelectedType(using: appContainer)
                                }
                            }
                        )
                        .frame(minWidth: 260, idealWidth: 320)
                    }
                    .frame(minHeight: 620)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailSpendTrendSection(for category: CategoryListItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("categories.monthlyTrend.title"))
                        .font(AppTypography.sectionTitle)

                    Text(appLanguage.localized("categories.monthlyTrend.subtitle", category.name))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            detailRangePicker

            let points = detailMonthlySpendPoints(for: category)

            if points.isEmpty {
                HStack(spacing: AppSpacing.medium) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.neutral)
                        .frame(width: 44, height: 44)
                        .background(AppColors.neutral.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("categories.monthlyTrend.empty.title"))
                            .font(.headline)

                        Text(LocalizedStringKey("categories.monthlyTrend.empty.message"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(AppSpacing.medium)
                .background(AppColors.cardBackground.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Mes", point.startDate),
                            y: .value("Gasto", decimalValue(point.amount))
                        )
                        .foregroundStyle(AppColors.neutral.opacity(0.16).gradient)

                        LineMark(
                            x: .value("Mes", point.startDate),
                            y: .value("Gasto", decimalValue(point.amount))
                        )
                        .foregroundStyle(AppColors.neutral.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Mes", point.startDate),
                            y: .value("Gasto", decimalValue(point.amount))
                        )
                        .foregroundStyle(AppColors.neutral)
                    }

                    if let selectedDetailDate {
                        RuleMark(x: .value("Mes", selectedDetailDate))
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
                .frame(height: 210)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: xAxisStride(for: points.count))) { value in
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
                                        updateCategoryDetailDateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        updateCategoryDetailDateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let selectedDetailDate,
                       let selectedPoint = points.min(by: {
                           abs($0.startDate.timeIntervalSince(selectedDetailDate)) < abs($1.startDate.timeIntervalSince(selectedDetailDate))
                       }) {
                        InChartCalloutOverlay(
                            title: selectedPoint.monthLabel,
                            items: [
                                InChartCalloutOverlayItem(label: appLanguage == .spanish ? "Gasto" : "Expenses", value: formattedAmount(selectedPoint.amount), color: AppColors.expense)
                            ],
                            alignment: .topLeading
                        )
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: AppSpacing.small)], spacing: AppSpacing.small) {
                    detailMetric(
                        title: LocalizedStringKey("categories.detail.total"),
                        value: formattedAmount(points.reduce(.zero) { $0 + $1.amount })
                    )

                    detailMetric(
                        title: LocalizedStringKey("categories.detail.average"),
                        value: formattedAmount(points.reduce(.zero) { $0 + $1.amount } / Decimal(points.count))
                    )

                    if let peak = points.max(by: { $0.amount < $1.amount }) {
                        detailMetric(
                            title: LocalizedStringKey("categories.detail.peak"),
                            value: formattedAmount(peak.amount),
                            detail: peak.monthLabel
                        )
                    }

                    detailMetric(
                        title: LocalizedStringKey("categories.detail.months"),
                        value: appLanguage.formatInteger(points.count)
                    )
                }
            }
        }
        .padding(AppSpacing.medium)
        .glassCard(material: AppMaterials.groupedGlass)
        .onChange(of: selectedDetailRange) { _, _ in
            selectedDetailDate = nil
        }
    }

    private func updateCategoryDetailDateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        let xPosition = location.x - plotFrame.origin.x
        guard xPosition >= 0, xPosition <= plotFrame.size.width,
              let date: Date = proxy.value(atX: xPosition, as: Date.self) else { return }
        selectedDetailDate = date
    }

    private var detailRangePicker: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Label(LocalizedStringKey("categories.detail.period"), systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker(LocalizedStringKey("categories.detail.period"), selection: $selectedDetailRange) {
                ForEach(AnalysisTimeRange.allCases) { range in
                    Text(rangeLabel(range)).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)
            .labelsHidden()
            .frame(maxWidth: 520)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.xSmall)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rangeLabel(_ range: AnalysisTimeRange) -> String {
        switch range {
        case .month: return appLanguage.localized("categories.detail.range.month")
        case .threeMonths: return appLanguage.localized("categories.detail.range.threeMonths")
        case .sixMonths: return appLanguage.localized("categories.detail.range.sixMonths")
        case .year: return appLanguage.localized("categories.detail.range.year")
        case .all: return appLanguage.localized("categories.detail.range.all")
        }
    }

    private func detailHeader(for category: CategoryListItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                Button {
                    selectedCategory = nil
                    transactionsViewModel.filterCategoryID = nil
                    transactionsViewModel.searchText = ""
                } label: {
                    Label(LocalizedStringKey("All Categories"), systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                SummaryChip(
                    value: "\(transactionsViewModel.sortedTransactions.count)",
                    label: "Movements"
                )
                .frame(maxWidth: 150)
            }

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack(alignment: .center, spacing: AppSpacing.small) {
                    Text(category.name)
                        .font(.title2.weight(.semibold))

                    if category.isSystem {
                        Text(LocalizedStringKey("System"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.neutral)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppColors.neutral.opacity(0.12), in: Capsule())
                    }
                }

                HStack(spacing: AppSpacing.small) {
                    Text(LocalizedStringKey(category.group))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Circle()
                        .fill(AppColors.neutral.opacity(0.35))
                        .frame(width: 4, height: 4)

                    Text(detailSummary(for: category))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryEmptyState(for category: CategoryListItem) -> some View {
        VStack(spacing: AppSpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppColors.neutral.opacity(0.10))

                Image(systemName: "tray")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppColors.neutral)
            }
            .frame(width: 64, height: 64)

            VStack(spacing: AppSpacing.small) {
                Text(LocalizedStringKey("No movements in this category"))
                    .font(.title3.weight(.semibold))

                Text(appLanguage.localized("categories.emptyDetail.message", category.name))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.large)
    }

    private func detailSummary(for category: CategoryListItem) -> String {
        let count = transactionsViewModel.sortedTransactions.count
        if count == 1 {
            return appLanguage.localized("categories.associatedMovement.one")
        }
        return appLanguage.localized("categories.associatedMovement.many", appLanguage.formatInteger(count))
    }

    private func reloadData() {
        viewModel.load(using: appContainer)
        transactionsViewModel.load(using: appContainer)
        syncDetailState()
    }

    private func openCategoryDetail(_ category: CategoryListItem) {
        selectedCategory = category
        transactionsViewModel.searchText = ""
        applyCategoryFilter(for: category.id)
    }

    private func syncDetailState() {
        guard let currentSelection = selectedCategory else { return }

        if let refreshedCategory = viewModel.categories.first(where: { $0.id == currentSelection.id }) {
            selectedCategory = refreshedCategory
            applyCategoryFilter(for: refreshedCategory.id)
        } else {
            selectedCategory = nil
            transactionsViewModel.filterCategoryID = nil
            transactionsViewModel.selectedTransaction = nil
        }
    }

    private func applyCategoryFilter(for categoryID: UUID) {
        transactionsViewModel.filterCategoryID = categoryID

        let filteredTransactions = transactionsViewModel.sortedTransactions
        if let selectedTransaction = transactionsViewModel.selectedTransaction,
           filteredTransactions.contains(where: { $0.id == selectedTransaction.id }) {
            transactionsViewModel.select(selectedTransaction)
        } else if let firstTransaction = filteredTransactions.first {
            transactionsViewModel.select(firstTransaction)
        } else {
            transactionsViewModel.selectedTransaction = nil
            transactionsViewModel.selectedCategoryID = categoryID
            transactionsViewModel.statusMessage = nil
        }
    }

    private func detailMonthlySpendPoints(for category: CategoryListItem) -> [DetailMonthlySpendPoint] {
        let categoryMap = Dictionary(uniqueKeysWithValues: transactionsViewModel.categories.map { ($0.id, $0.name) })
        let reportingEntries = FinancialReportingScope(now: Date(), dateBasis: .budget)
            .eligibleEntries(
                from: transactionsViewModel.transactions,
                classifier: FinancialMovementClassifier(),
                categoryMap: categoryMap
            )
            .filter { $0.transaction.categoryID == category.id }
            .filter { FinancialMovementClassifier().isExpense($0.transaction) }

        let filtered = filterEntries(reportingEntries, for: selectedDetailRange)
        guard let latestDate = reportingEntries.map(\.date).max() else { return [] }
        let endMonth = startOfMonth(for: latestDate)
        let startMonth: Date = if let monthWindow = selectedDetailRange.monthWindow {
            Calendar.current.date(byAdding: .month, value: -(monthWindow - 1), to: endMonth) ?? endMonth
        } else {
            reportingEntries.map(\.date).min().map(startOfMonth(for:)) ?? endMonth
        }
        let grouped = Dictionary(grouping: filtered, by: { startOfMonth(for: $0.date) })
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        formatter.locale = Locale.current

        var months: [Date] = []
        var month = startMonth
        while month <= endMonth {
            months.append(month)
            guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: month) else { break }
            month = nextMonth
        }

        return months.map { month in
            let items = grouped[month] ?? []
            let amount = items.reduce(Decimal.zero) { partial, entry in
                partial + absolute(entry.amount)
            }

            return DetailMonthlySpendPoint(
                id: month.formatted(.dateTime.year().month()),
                monthLabel: formatter.string(from: month),
                startDate: month,
                amount: amount
            )
        }
    }

    private func filterEntries(_ transactions: [FinancialReportingEntry], for range: AnalysisTimeRange) -> [FinancialReportingEntry] {
        guard let monthWindow = range.monthWindow,
              let latestDate = transactions.map(\.date).max(),
              let startDate = Calendar.current.date(byAdding: .month, value: -(monthWindow - 1), to: startOfMonth(for: latestDate)) else {
            return transactions.sorted { $0.date < $1.date }
        }

        return transactions
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
    }

    private func xAxisStride(for pointCount: Int) -> Int {
        switch pointCount {
        case 0...6: return 1
        case 7...12: return 2
        default: return 3
        }
    }

    private func startOfMonth(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private func absolute(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }

    private func decimalValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private func formattedAmount(_ value: Decimal) -> String {
        value.privacyFormatted(hidden: isPrivacyModeEnabled, currencyCode: AppConfig.defaultCurrencyCode)
    }

    private func detailMetric(title: LocalizedStringKey, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DetailMonthlySpendPoint: Identifiable {
    let id: String
    let monthLabel: String
    let startDate: Date
    let amount: Decimal
}

// MARK: - Category Card

private struct CategoryCard: View {
    let item: CategoryListItem
    let onTap: () -> Void
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var isHovered = false

    private var systemImage: String {
        switch item.name.lowercased() {
        case let n where n.contains("aliment"): return "cart.fill"
        case let n where n.contains("restaur"): return "fork.knife"
        case let n where n.contains("transporte"): return "car.fill"
        case let n where n.contains("suscripcion"), let n where n.contains("suscripción"): return "iphone"
        case let n where n.contains("ingreso"), let n where n.contains("nomina"): return "banknote.fill"
        case let n where n.contains("salud"), let n where n.contains("farma"): return "cross.case.fill"
        case let n where n.contains("ocio"), let n where n.contains("entretenimiento"): return "film.fill"
        case let n where n.contains("hogar"), let n where n.contains("casa"): return "house.fill"
        case let n where n.contains("ropa"), let n where n.contains("moda"): return "tshirt.fill"
        case let n where n.contains("viaje"), let n where n.contains("hotel"): return "airplane"
        case let n where n.contains("educacion"), let n where n.contains("educación"): return "book.fill"
        case let n where n.contains("deporte"), let n where n.contains("gym"): return "figure.run"
        default: return item.group == "Income" ? "banknote.fill" : "shippingbox.fill"
        }
    }

    private var tint: Color {
        item.group == "Income" ? AppColors.income : AppColors.neutral
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tint.opacity(0.12))

                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(tint.opacity(0.10), lineWidth: 1)

                        Image(systemName: systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .frame(width: 48, height: 48)

                    Spacer()

                    VStack(alignment: .trailing, spacing: AppSpacing.xSmall) {
                        Text("\(item.transactionCount)")
                            .font(.headline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(tint.opacity(0.14), in: Capsule())

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(LocalizedStringKey(item.group))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: AppSpacing.xSmall) {
                    if item.isSystem {
                        Text(LocalizedStringKey("System"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(tint.opacity(0.10), in: Capsule())
                    }

                    Spacer(minLength: 0)

                    Text(appLanguage.localized(
                        "categories.shareOfMovements",
                        appLanguage.formatPercent(item.activityShare)
                    ))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.medium)
            .glassCard(material: AppMaterials.subtleGlass)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(tint.opacity(isHovered ? 0.22 : 0.10), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

private struct SummaryChip: View {
    let value: String
    let label: String

    private var accent: Color {
        switch label {
        case "Income", "Ingresos":
            return AppColors.income
        case "System", "Sistema":
            return AppColors.neutral
        default:
            return AppColors.accent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(label))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 84, alignment: .leading)
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.medium)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(accent.opacity(0.82))
                .frame(width: 32, height: 4)
                .padding(.top, 10)
                .padding(.leading, AppSpacing.medium)
        }
    }
}
