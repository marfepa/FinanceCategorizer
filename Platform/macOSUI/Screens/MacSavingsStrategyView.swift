import SwiftUI

struct MacSavingsStrategyView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("isPrivacyModeEnabled") private var privacyStoredValue = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = SavingsStrategyViewModel()
    @Namespace private var presetNamespace

    var body: some View {
        GlassPageScaffold {
            header
        } content: {
            if viewModel.isLoading && viewModel.snapshot == nil {
                LoadingView(title: LocalizedStringKey("strategy.loading"))
            } else if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                    chromeBar
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
                    systemImage: "chart.pie"
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
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            Text(LocalizedStringKey("strategy.title"))
                .font(AppTypography.displayTitle)
            Text(LocalizedStringKey("strategy.subtitle"))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 560, alignment: .leading)
        }
    }

    private var chromeBar: some View {
        LiquidGlassContainer(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(visiblePresets) { preset in
                        presetChip(preset)
                    }
                }

                Spacer(minLength: 12)

                monthControl

                Button {
                    privacyStoredValue.toggle()
                } label: {
                    Image(systemName: privacyStoredValue ? "eye.slash.fill" : "eye.fill")
                }
                .buttonStyle(.plain)
                .help(privacyStoredValue ? LocalizedStringKey("Show amounts") : LocalizedStringKey("Hide amounts"))
                .appSecondaryGlassButton()
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlassPanel(
                padding: 0,
                radius: AppRadius.card,
                material: AppMaterials.subtleGlass,
                tint: .white,
                interactive: true,
                shadowRadius: 14,
                shadowY: 8
            )
        }
    }

    private var monthControl: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.shiftMonth(by: -1, using: appContainer)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canShift(-1))
            .buttonStyle(.plain)

            Text(monthTitle)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 128)

            Button {
                viewModel.shiftMonth(by: 1, using: appContainer)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!canShift(1))
            .buttonStyle(.plain)
        }
        .foregroundStyle(.primary)
    }

    private func presetChip(_ preset: SavingsStrategyPreset) -> some View {
        let isSelected = viewModel.config.preset == preset
        return Button {
            viewModel.applyPreset(preset, using: appContainer)
        } label: {
            Text(LocalizedStringKey(preset.titleKey))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        .modifier(MorphingPresetStyle(isSelected: isSelected, id: preset.rawValue, namespace: presetNamespace))
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
        HStack(alignment: .center, spacing: 36) {
            VStack(spacing: 14) {
                SavingsStrategyRingsView(snapshot: snapshot, size: 204)
                SavingsStrategyLegend()
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(LocalizedStringKey(snapshot.isOnTrack ? "strategy.hero.onTrack" : "strategy.hero.offTrack"))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(snapshot.isOnTrack ? AppColors.income : AppColors.warning)

                Text(heroDetail(snapshot))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420, alignment: .leading)

                HStack(alignment: .firstTextBaseline, spacing: 28) {
                    heroMetric(LocalizedStringKey("strategy.income"), renderAmount(snapshot.income))
                    heroMetric(LocalizedStringKey("strategy.unassigned"), renderAmount(snapshot.unassignedAmount))
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .liquidGlassHero(padding: 32, tint: snapshot.isOnTrack ? AppColors.income : AppColors.warning)
    }

    private func heroMetric(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
        }
    }

    private func bucketGrid(_ snapshot: SavingsStrategySnapshot) -> some View {
        HStack(alignment: .top, spacing: AppLayoutMetrics.contentGap) {
            ForEach(snapshot.buckets) { result in
                StrategyBucketCard(
                    result: result,
                    renderAmount: renderAmount,
                    percentLabel: percentLabel,
                    targetCaption: appLanguage.localized("strategy.target", "\(result.targetPercent)"),
                    onDecrease: { viewModel.adjust(bucket: result.bucket, delta: -1, using: appContainer) },
                    onIncrease: { viewModel.adjust(bucket: result.bucket, delta: 1, using: appContainer) },
                    residualText: result.bucket == .investment && result.residualAmount > .zero
                        ? appLanguage.localized("strategy.residual", renderAmount(result.residualAmount))
                        : nil
                )
            }
        }
    }

    private var mappingSection: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack(alignment: .firstTextBaseline) {
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

            HStack(alignment: .top, spacing: 18) {
                mappingColumn(titleKey: "strategy.bucket.needs", bucket: .needs)
                mappingColumn(titleKey: "strategy.bucket.wants", bucket: .wants)
                mappingColumn(titleKey: "strategy.bucket.investment", bucket: .investment)
            }
        }
        .contentCard(padding: 22, radius: AppRadius.panelGroup)
    }

    private func mappingColumn(titleKey: String, bucket: SavingsAllocationBucket) -> some View {
        let items = viewModel.assignableCategories(in: bucket)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(bucket.tintColor).frame(width: 7, height: 7)
                Text(LocalizedStringKey(titleKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
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
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                            Text(category.name)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.primary.opacity(0.035))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func unassignedSection(_ snapshot: SavingsStrategySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
        .contentCard(padding: 20, radius: AppRadius.card)
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

private struct StrategyBucketCard: View {
    let result: SavingsStrategyBucketResult
    let renderAmount: (Decimal) -> String
    let percentLabel: (Double) -> String
    let targetCaption: String
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let residualText: String?
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: result.bucket.systemImage)
                    .foregroundStyle(result.bucket.tintColor)
                    .frame(width: 28, height: 28)
                    .background(result.bucket.tintColor.opacity(0.12), in: Circle())
                Text(LocalizedStringKey(result.bucket.titleKey))
                    .font(.headline)
                Spacer()
                Text(LocalizedStringKey(SavingsStrategyStatusStyle.key(result.status, bucket: result.bucket)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SavingsStrategyStatusStyle.color(result.status, bucket: result.bucket))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(percentLabel(result.actualPercent))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(SavingsStrategyStatusStyle.color(result.status, bucket: result.bucket))
                Text(targetCaption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            targetBar

            Text(renderAmount(result.actualAmount))
                .font(.headline.monospacedDigit())
            Text(LocalizedStringKey(result.bucket.subtitleKey))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onDecrease) { Image(systemName: "minus") }
                    .appSecondaryGlassButton()
                    .controlSize(.small)
                Text("\(result.targetPercent)%")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 36)
                Button(action: onIncrease) { Image(systemName: "plus") }
                    .appSecondaryGlassButton()
                    .controlSize(.small)
            }

            if let residualText {
                Text(residualText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if result.categories.isEmpty {
                Text(LocalizedStringKey("strategy.noMovements"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(result.categories.prefix(4)) { item in
                        HStack {
                            Text(item.name)
                                .lineLimit(1)
                            Spacer()
                            Text(renderAmount(item.amount))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.panelGroup, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.panelGroup, style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovering ? 0.12 : 0.06), lineWidth: 1)
        }
        .scaleEffect(isHovering ? 1.01 : 1)
        .shadow(color: .black.opacity(isHovering ? 0.08 : 0.04), radius: isHovering ? 16 : 10, y: isHovering ? 8 : 4)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                isHovering = hovering
            }
        }
    }

    private var targetBar: some View {
        GeometryReader { proxy in
            let progress = min(max(result.actualPercent / max(Double(result.targetPercent), 1), 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(result.bucket.tintColor.opacity(0.12))
                Capsule()
                    .fill(SavingsStrategyStatusStyle.color(result.status, bucket: result.bucket))
                    .frame(width: max(6, proxy.size.width * CGFloat(progress)))
            }
        }
        .frame(height: 6)
    }
}

private struct MorphingPresetStyle: ViewModifier {
    let isSelected: Bool
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            if isSelected {
                content
                    .glassEffect(Glass.regular.interactive(), in: Capsule(style: .continuous))
                    .glassEffectID(id, in: namespace)
            } else {
                content.glassEffectID(id, in: namespace)
            }
        } else if isSelected {
            content.background(Capsule(style: .continuous).fill(Color.primary.opacity(0.08)))
        } else {
            content
        }
    }
}
