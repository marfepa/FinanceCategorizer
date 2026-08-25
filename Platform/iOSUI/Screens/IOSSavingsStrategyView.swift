import SwiftUI

struct IOSSavingsStrategyView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("isPrivacyModeEnabled") private var privacyStoredValue = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = SavingsStrategyViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if viewModel.isLoading && viewModel.snapshot == nil {
                    LoadingView(title: LocalizedStringKey("strategy.loading"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.xxLarge)
                } else if let snapshot = viewModel.snapshot {
                    chrome
                    hero(snapshot)
                    ForEach(snapshot.buckets) { result in
                        bucketCard(result)
                    }
                    mappingCard
                    if snapshot.unassignedAmount > .zero {
                        unassignedCard(snapshot)
                    }
                } else {
                    EmptyStateView(
                        title: LocalizedStringKey("strategy.empty.title"),
                        message: LocalizedStringKey("strategy.empty.message"),
                        systemImage: "chart.pie"
                    )
                    .padding(.top, AppSpacing.xxLarge)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(AppColors.expense)
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.large)
        }
        .background(AppColors.background)
        .navigationTitle(LocalizedStringKey("strategy.title"))
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
        .task {
            viewModel.load(using: appContainer)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            viewModel.load(using: appContainer)
        }
    }

    private var chrome: some View {
        VStack(spacing: 10) {
            HStack {
                Button { viewModel.shiftMonth(by: -1, using: appContainer) } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canShift(-1))
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                    .monospacedDigit()
                Spacer()
                Button { viewModel.shiftMonth(by: 1, using: appContainer) } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canShift(1))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SavingsStrategyPreset.allCases.filter { $0 != .custom }) { preset in
                        let selected = viewModel.config.preset == preset
                        Button {
                            viewModel.applyPreset(preset, using: appContainer)
                        } label: {
                            Text(LocalizedStringKey(preset.titleKey))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .background {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(Color.primary.opacity(0.08))
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlassPanel(
            padding: 0,
            radius: AppRadius.card,
            material: AppMaterials.subtleGlass,
            tint: .white,
            interactive: true
        )
    }

    private func hero(_ snapshot: SavingsStrategySnapshot) -> some View {
        VStack(spacing: 16) {
            SavingsStrategyRingsView(snapshot: snapshot, size: 172)
            SavingsStrategyLegend()
            Text(LocalizedStringKey(snapshot.isOnTrack ? "strategy.hero.onTrack" : "strategy.hero.offTrack"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(snapshot.isOnTrack ? AppColors.income : AppColors.warning)
                .multilineTextAlignment(.center)
            Text(heroDetail(snapshot))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                labeledValue(LocalizedStringKey("strategy.income"), renderAmount(snapshot.income))
                labeledValue(LocalizedStringKey("strategy.unassigned"), renderAmount(snapshot.unassignedAmount))
            }
        }
        .frame(maxWidth: .infinity)
        .liquidGlassHero(padding: AppSpacing.large, tint: snapshot.isOnTrack ? AppColors.income : AppColors.warning)
    }

    private func labeledValue(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private func bucketCard(_ result: SavingsStrategyBucketResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.bucket.systemImage)
                    .foregroundStyle(result.bucket.tintColor)
                Text(LocalizedStringKey(result.bucket.titleKey))
                    .font(.headline)
                Spacer()
                Text(LocalizedStringKey(SavingsStrategyStatusStyle.key(result.status, bucket: result.bucket)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SavingsStrategyStatusStyle.color(result.status, bucket: result.bucket))
            }

            HStack(alignment: .firstTextBaseline) {
                Text(percentLabel(result.actualPercent))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(SavingsStrategyStatusStyle.color(result.status, bucket: result.bucket))
                Text(appLanguage.localized("strategy.target", "\(result.targetPercent)"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(renderAmount(result.actualAmount))
                    .font(.headline.monospacedDigit())
            }

            ProgressView(value: min(result.actualPercent / max(Double(result.targetPercent), 1), 1))
                .tint(SavingsStrategyStatusStyle.color(result.status, bucket: result.bucket))

            Text(LocalizedStringKey(result.bucket.subtitleKey))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button { viewModel.adjust(bucket: result.bucket, delta: -1, using: appContainer) } label: {
                    Image(systemName: "minus")
                }
                .appSecondaryGlassButton()
                Text("\(result.targetPercent)%")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Button { viewModel.adjust(bucket: result.bucket, delta: 1, using: appContainer) } label: {
                    Image(systemName: "plus")
                }
                .appSecondaryGlassButton()
            }

            ForEach(result.categories.prefix(4)) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text(renderAmount(item.amount))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
        .contentCard(padding: 18, radius: AppRadius.card)
    }

    private var mappingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Text(LocalizedStringKey("strategy.mapping.title"))
                    .font(.headline)
                Spacer()
                Button(LocalizedStringKey("strategy.mapping.reset")) {
                    viewModel.resetAssignments(using: appContainer)
                }
                .font(.caption)
            }
            Text(LocalizedStringKey("strategy.mapping.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(viewModel.categories, id: \.id) { category in
                HStack {
                    Image(systemName: category.iconName)
                    Text(category.name)
                    Spacer()
                    Picker("", selection: assignmentBinding(for: category)) {
                        Text(LocalizedStringKey("strategy.unassigned")).tag(Optional<SavingsAllocationBucket>.none)
                        ForEach(SavingsAllocationBucket.allCases) { bucket in
                            Text(LocalizedStringKey(bucket.titleKey)).tag(Optional(bucket))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 160)
                }
                .font(.subheadline)
            }
        }
        .contentCard(padding: AppSpacing.medium, radius: AppRadius.card)
    }

    private func unassignedCard(_ snapshot: SavingsStrategySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("strategy.unassigned.title"))
                .font(.headline)
            Text(appLanguage.localized("strategy.unassigned.detail", renderAmount(snapshot.unassignedAmount)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentCard(padding: AppSpacing.medium, radius: AppRadius.card)
    }

    private func assignmentBinding(for category: Category) -> Binding<SavingsAllocationBucket?> {
        Binding(
            get: { viewModel.config.bucket(for: category) },
            set: { viewModel.assign(categoryID: category.id, to: $0, using: appContainer) }
        )
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
