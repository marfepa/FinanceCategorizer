import SwiftUI

struct MacSavingsStrategyView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("isPrivacyModeEnabled") private var privacyStoredValue = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = SavingsStrategyViewModel()


    var body: some View {
        GlassPageScaffold {
            header
        } content: {
            if viewModel.isLoading && viewModel.snapshot == nil {
                LoadingView(title: LocalizedStringKey("strategy.loading"))
            } else if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                    controls
                    hero(snapshot)
                    bucketGrid(snapshot)
                    mappingSection
                    if snapshot.unassignedAmount > .zero || !snapshot.unassignedCategories.isEmpty {
                        unassignedSection(snapshot)
                    }
                }
            } else {
                EmptyStateView(
                    title: LocalizedStringKey("strategy.empty.title"),
                    message: LocalizedStringKey("strategy.empty.message"),
                    systemImage: "circle.hexagongrid"
                )
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(AppColors.expense)
                    .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.card)
            }
        }
        .task {
            viewModel.load(using: appContainer)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            viewModel.load(using: appContainer)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppLayoutMetrics.contentGap) {
            VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                Text(LocalizedStringKey("strategy.title"))
                    .font(AppTypography.displayTitle)
                Text(LocalizedStringKey("strategy.subtitle"))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            monthControl
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
        }
    }

    private var monthControl: some View {
        HStack(spacing: 6) {
            Button {
                viewModel.shiftMonth(by: -1, using: appContainer)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canShift(-1))
            .buttonStyle(.plain)

            Text(monthTitle)
                .font(.headline)
                .monospacedDigit()
                .frame(minWidth: 140)

            Button {
                viewModel.shiftMonth(by: 1, using: appContainer)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!canShift(1))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .liquidGlassPill(padding: 0, tint: .white, interactive: true)
        .controlSize(.small)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            Text(LocalizedStringKey("strategy.presets"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LiquidGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(visiblePresets) { preset in
                        presetChip(preset)
                    }
                    Spacer()
                    Button(LocalizedStringKey("strategy.reset")) {
                        viewModel.resetStrategy(using: appContainer)
                    }
                    .font(.caption.weight(.semibold))
                    .appSecondaryGlassButton()
                    .controlSize(.small)
                }
            }
        }
        .liquidGlassPanel(
            padding: AppLayoutMetrics.contentGap,
            radius: AppRadius.card,
            material: AppMaterials.subtleGlass,
            tint: .white,
            interactive: true,
            shadowRadius: 12,
            shadowY: 6
        )
    }

    private func presetChip(_ preset: SavingsStrategyPreset) -> some View {
        let isSelected = viewModel.config.preset == preset
        return Button {
            viewModel.applyPreset(preset, using: appContainer)
        } label: {
            Text(LocalizedStringKey(preset.titleKey))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        .background {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSelected)
        .disabled(preset == .custom)
    }

    private var visiblePresets: [SavingsStrategyPreset] {
        var presets = SavingsStrategyPreset.allCases.filter { $0 != .custom }
        if viewModel.config.preset == .custom {
            presets.append(.custom)
        }
        return presets
    }

    private func hero(_ snapshot: SavingsStrategySnapshot) -> some View {
        HStack(alignment: .center, spacing: AppLayoutMetrics.blockGap) {
            SavingsStrategyRingsView(snapshot: snapshot, size: 210)

            VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
                Text(LocalizedStringKey(snapshot.isOnTrack ? "strategy.hero.onTrack" : "strategy.hero.offTrack"))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(snapshot.isOnTrack ? AppColors.income : AppColors.warning)

                Text(heroDetail(snapshot))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppLayoutMetrics.contentGap) {
                    heroMetric(
                        title: LocalizedStringKey("strategy.income"),
                        value: renderAmount(snapshot.income)
                    )
                    heroMetric(
                        title: LocalizedStringKey("strategy.unassigned"),
                        value: renderAmount(snapshot.unassignedAmount)
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .liquidGlassHero(padding: AppLayoutMetrics.liquidHeroInset, tint: snapshot.isOnTrack ? AppColors.income : AppColors.warning)
    }

    private func heroMetric(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlassPill(padding: 0, tint: .white)
    }

    private func bucketGrid(_ snapshot: SavingsStrategySnapshot) -> some View {
        HStack(alignment: .top, spacing: AppLayoutMetrics.contentGap) {
            ForEach(snapshot.buckets) { result in
                bucketCard(result)
            }
        }
    }

    private func bucketCard(_ result: SavingsStrategyBucketResult) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack {
                Image(systemName: result.bucket.systemImage)
                    .foregroundStyle(result.bucket.tintColor)
                Text(LocalizedStringKey(result.bucket.titleKey))
                    .font(AppTypography.sectionTitle)
                Spacer()
                statusPill(result.status, bucket: result.bucket)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(percentLabel(result.actualPercent))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(statusColor(result.status, bucket: result.bucket))
                Text(appLanguage.localized("strategy.target", "\(result.targetPercent)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            targetBar(result)

            Text(renderAmount(result.actualAmount))
                .font(.headline.monospacedDigit())
            Text(LocalizedStringKey(result.bucket.subtitleKey))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    viewModel.adjust(bucket: result.bucket, delta: -1, using: appContainer)
                } label: {
                    Image(systemName: "minus")
                }
                .appSecondaryGlassButton()
                .controlSize(.small)

                Text("\(result.targetPercent)%")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 44)

                Button {
                    viewModel.adjust(bucket: result.bucket, delta: 1, using: appContainer)
                } label: {
                    Image(systemName: "plus")
                }
                .appSecondaryGlassButton()
                .controlSize(.small)
            }

            if result.bucket == .investment, result.residualAmount > .zero {
                Text(appLanguage.localized("strategy.residual", renderAmount(result.residualAmount)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.35)

            if result.categories.isEmpty {
                Text(LocalizedStringKey("strategy.noMovements"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(result.categories.prefix(5)) { item in
                    HStack {
                        Label(item.name, systemImage: item.iconName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(renderAmount(item.amount))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private func targetBar(_ result: SavingsStrategyBucketResult) -> some View {
        GeometryReader { proxy in
            let progress = min(max(result.actualPercent / max(Double(result.targetPercent), 1), 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(result.bucket.tintColor.opacity(0.12))
                Capsule()
                    .fill(statusColor(result.status, bucket: result.bucket))
                    .frame(width: max(8, proxy.size.width * CGFloat(progress)))
            }
        }
        .frame(height: 7)
    }

    private var mappingSection: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("strategy.mapping.title"))
                        .font(AppTypography.sectionTitle)
                    Text(LocalizedStringKey("strategy.mapping.subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(LocalizedStringKey("strategy.mapping.reset")) {
                    viewModel.resetAssignments(using: appContainer)
                }
                .appSecondaryGlassButton()
                .controlSize(.small)
            }

            HStack(alignment: .top, spacing: AppLayoutMetrics.contentGap) {
                mappingColumn(titleKey: "strategy.bucket.needs", bucket: .needs)
                mappingColumn(titleKey: "strategy.bucket.wants", bucket: .wants)
                mappingColumn(titleKey: "strategy.bucket.investment", bucket: .investment)
                mappingColumn(titleKey: "strategy.unassigned", bucket: nil)
            }
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private func mappingColumn(titleKey: String, bucket: SavingsAllocationBucket?) -> some View {
        let items = bucket.map { viewModel.assignableCategories(in: $0) } ?? viewModel.unassignedCategories()
        return VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text(LocalizedStringKey("strategy.mapping.empty"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(items, id: \.id) { category in
                    Menu {
                        Button(LocalizedStringKey("strategy.bucket.needs")) {
                            viewModel.assign(categoryID: category.id, to: .needs, using: appContainer)
                        }
                        Button(LocalizedStringKey("strategy.bucket.wants")) {
                            viewModel.assign(categoryID: category.id, to: .wants, using: appContainer)
                        }
                        Button(LocalizedStringKey("strategy.bucket.investment")) {
                            viewModel.assign(categoryID: category.id, to: .investment, using: appContainer)
                        }
                        Button(LocalizedStringKey("strategy.unassigned")) {
                            viewModel.assign(categoryID: category.id, to: nil, using: appContainer)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: category.iconName)
                                .frame(width: 14)
                            Text(category.name)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func unassignedSection(_ snapshot: SavingsStrategySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("strategy.unassigned.title"))
                .font(AppTypography.sectionTitle)
            Text(appLanguage.localized("strategy.unassigned.detail", renderAmount(snapshot.unassignedAmount)))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(snapshot.unassignedCategories) { item in
                HStack {
                    Label(item.name, systemImage: item.iconName)
                    Spacer()
                    Text(renderAmount(item.amount))
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.card)
    }

    private func statusPill(_ status: SavingsStrategyRangeStatus, bucket: SavingsAllocationBucket) -> some View {
        Text(LocalizedStringKey(statusKey(status, bucket: bucket)))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor(status, bucket: bucket))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status, bucket: bucket).opacity(0.12), in: Capsule())
    }

    private func statusKey(_ status: SavingsStrategyRangeStatus, bucket: SavingsAllocationBucket) -> String {
        switch status {
        case .within: return "strategy.range.within"
        case .over: return bucket == .investment ? "strategy.range.above" : "strategy.range.over"
        case .under: return "strategy.range.under"
        }
    }

    private func statusColor(_ status: SavingsStrategyRangeStatus, bucket: SavingsAllocationBucket) -> Color {
        switch status {
        case .within:
            return AppColors.income
        case .over:
            return bucket == .investment ? AppColors.income : AppColors.expense
        case .under:
            return AppColors.warning
        }
    }

    private func heroDetail(_ snapshot: SavingsStrategySnapshot) -> String {
        if !snapshot.hasIncome {
            return appLanguage.localized("strategy.hero.noIncome")
        }
        if snapshot.isOnTrack {
            return appLanguage.localized("strategy.hero.onTrack.detail")
        }
        if let off = snapshot.buckets.first(where: { !$0.status.isOnTrack }) {
            return appLanguage.localized(
                "strategy.hero.offTrack.detail",
                appLanguage.localized(off.bucket.titleKey),
                percentLabel(abs(off.deltaPercentPoints))
            )
        }
        return appLanguage.localized("strategy.hero.offTrack.detail.generic")
    }

    private var monthTitle: String {
        guard let selected = viewModel.selectedMonthStart ?? viewModel.snapshot?.monthStart else {
            return appLanguage.localized("strategy.month.current")
        }
        let formatter = DateFormatter()
        formatter.locale = appLanguage.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: selected).capitalized
    }

    private func canShift(_ value: Int) -> Bool {
        guard let selected = viewModel.selectedMonthStart,
              let index = viewModel.availableMonths.firstIndex(of: selected) else {
            return false
        }
        return viewModel.availableMonths.indices.contains(index - value)
    }

    private func percentLabel(_ value: Double) -> String {
        appLanguage.formatPercent(value / 100, fractionDigits: value.rounded() == value ? 0 : 1)
    }

    private func renderAmount(_ value: Decimal) -> String {
        value.privacyFormatted(hidden: privacyStoredValue, language: appLanguage)
    }
}


