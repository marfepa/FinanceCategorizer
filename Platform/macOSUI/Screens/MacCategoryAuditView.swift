import SwiftUI

struct MacCategoryAuditView: View {
    @Environment(\.appContainer) private var appContainer
    @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = CategoryAuditViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            header
            summary

            HSplitView {
                auditTable
                    .frame(minWidth: 760)

                CategoryAuditInspectorView(
                    transaction: viewModel.selectedTransaction,
                    viewModel: viewModel,
                    onAccept: { viewModel.accept($0, using: appContainer) },
                    onDismiss: { viewModel.dismiss($0, using: appContainer) }
                )
                .frame(minWidth: 320, idealWidth: AppLayoutMetrics.maxInspectorWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
        }
        .padding(AppLayoutMetrics.sectionGap)
        .background(AppColors.background)
        .navigationTitle(LocalizedStringKey("audit.title"))
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await viewModel.analyzeAll(using: appContainer) }
                } label: {
                    Label(
                        viewModel.isAnalyzing
                            ? LocalizedStringKey("audit.action.analyzing")
                            : LocalizedStringKey("audit.action.analyzeAll"),
                        systemImage: viewModel.isAnalyzing ? "hourglass" : "sparkles"
                    )
                }
                .disabled(viewModel.isAnalyzing || viewModel.transactions.isEmpty)

                Menu {
                    Button {
                        Task { await viewModel.analyzeSelection(using: appContainer) }
                    } label: {
                        Label(LocalizedStringKey("audit.action.analyzeSelection"), systemImage: "scope")
                    }
                    .disabled(viewModel.selectedTransactionIDs.isEmpty || viewModel.isAnalyzing)

                    Button {
                        viewModel.acceptSelected(using: appContainer)
                    } label: {
                        Label(LocalizedStringKey("audit.action.acceptSelected"), systemImage: "checkmark.circle")
                    }
                    .disabled(viewModel.selectedTransactionIDs.isEmpty)

                    Button {
                        viewModel.dismissSelected(using: appContainer)
                    } label: {
                        Label(LocalizedStringKey("audit.action.dismissSelected"), systemImage: "xmark.circle")
                    }
                    .disabled(viewModel.selectedTransactionIDs.isEmpty)

                    Divider()

                    Button {
                        viewModel.acceptAllHighConfidence(using: appContainer)
                    } label: {
                        Label(LocalizedStringKey("audit.action.acceptHighConfidence"), systemImage: "checkmark.seal")
                    }
                } label: {
                    Label(LocalizedStringKey("audit.action.more"), systemImage: "ellipsis.circle")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: Text(LocalizedStringKey("audit.search")))
        .onAppear {
            viewModel.load(using: appContainer)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            viewModel.load(using: appContainer)
        }
        .overlay(alignment: .bottom) {
            if let message = viewModel.statusMessage ?? viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(viewModel.errorMessage == nil ? .secondary : AppColors.warning)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, AppSpacing.small)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(LocalizedStringKey("audit.title"))
                    .font(AppTypography.displayTitle)
                Text(LocalizedStringKey("audit.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if viewModel.selectedVisibleCount > 0 {
                HStack(spacing: AppSpacing.small) {
                    Text(appLanguage.localized("audit.selected", appLanguage.formatInteger(viewModel.selectedVisibleCount)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(LocalizedStringKey("Clear")) {
                        viewModel.clearSelection()
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private var summary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                auditMetric(
                    title: "audit.summary.analyzed",
                    value: viewModel.analyzedCount,
                    tint: AppColors.neutral,
                    systemImage: "checklist"
                )
                auditMetric(
                    title: "audit.summary.suggestions",
                    value: viewModel.suggestionCount,
                    tint: AppColors.warning,
                    systemImage: "sparkles"
                )
                auditMetric(
                    title: "audit.summary.uncategorized",
                    value: viewModel.uncategorizedCount,
                    tint: AppColors.expense,
                    systemImage: "questionmark.circle"
                )
                auditMetric(
                    title: "audit.summary.lowConfidence",
                    value: viewModel.lowConfidenceCount,
                    tint: AppColors.warning,
                    systemImage: "exclamationmark.triangle"
                )
                auditMetric(
                    title: "audit.summary.confirmed",
                    value: viewModel.confirmedCount,
                    tint: AppColors.income,
                    systemImage: "checkmark.seal"
                )
            }
        }
    }

    private var auditTable: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                Picker(LocalizedStringKey("audit.filter.title"), selection: $viewModel.filter) {
                    ForEach(CategoryAuditFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 620)

                Spacer()

                Button {
                    viewModel.selectAllVisible()
                } label: {
                    Label(LocalizedStringKey("audit.action.selectVisible"), systemImage: "checkmark.square")
                }
                .buttonStyle(.borderless)
            }

            if viewModel.visibleTransactions.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("audit.empty.title"),
                    systemImage: "rectangle.and.text.magnifyingglass",
                    description: Text(LocalizedStringKey("audit.empty.message"))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(viewModel.visibleTransactions, selection: $viewModel.selectedTransactionIDs) {
                    TableColumn(LocalizedStringKey("audit.column.date")) { transaction in
                        Text(appLanguage.format(date: transaction.bookingDate, dateStyle: .short))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 78, ideal: 92, max: 110)

                    TableColumn(LocalizedStringKey("audit.column.movement")) { transaction in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.merchantDisplayName ?? transaction.rawDescription)
                                .lineLimit(1)
                            if let merchant = transaction.merchantCanonicalName,
                               merchant != transaction.merchantDisplayName {
                                Text(merchant)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .width(min: 160, ideal: 240)

                    TableColumn(LocalizedStringKey("audit.column.amount")) { transaction in
                        Text(transaction.amount.privacyFormatted(
                            hidden: isPrivacyModeEnabled,
                            language: appLanguage,
                            currencyCode: transaction.currencyCode
                        ))
                        .font(AppTypography.amount)
                        .foregroundStyle(transaction.amount < 0 ? AppColors.expense : AppColors.income)
                    }
                    .width(min: 100, ideal: 120, max: 140)

                    TableColumn(LocalizedStringKey("audit.column.currentCategory")) { transaction in
                        Text(viewModel.categoryName(for: transaction.categoryID))
                            .lineLimit(1)
                    }
                    .width(min: 120, ideal: 150)

                    TableColumn(LocalizedStringKey("audit.column.suggestedCategory")) { transaction in
                        if let suggestedID = transaction.suggestedCategoryID {
                            Label(viewModel.categoryName(for: suggestedID), systemImage: "arrow.right")
                                .foregroundStyle(AppColors.warning)
                                .lineLimit(1)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 140, ideal: 170)

                    TableColumn(LocalizedStringKey("audit.column.confidence")) { transaction in
                        Text(appLanguage.formatPercent(viewModel.confidence(for: transaction)))
                            .font(.caption.monospacedDigit())
                    }
                    .width(min: 70, ideal: 82, max: 100)

                    TableColumn(LocalizedStringKey("audit.column.status")) { transaction in
                        Text(LocalizedStringKey(viewModel.statusKey(for: transaction)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor(for: transaction))
                    }
                    .width(min: 100, ideal: 120)
                }
                .onChange(of: viewModel.selectedTransactionIDs) { _, newValue in
                    guard let id = newValue.first else {
                        viewModel.selectedTransaction = nil
                        return
                    }
                    viewModel.selectedTransaction = viewModel.transactions.first(where: { $0.id == id })
                }
            }
        }
        .padding(AppSpacing.medium)
        .background(AppMaterials.contentMaterial, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private func auditMetric(title: String, value: Int, tint: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(LocalizedStringKey(title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(appLanguage.formatInteger(value))
                .font(.title2.weight(.semibold).monospacedDigit())
        }
        .frame(minWidth: 130, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(AppMaterials.groupedGlass, in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
    }

    private func statusColor(for transaction: Transaction) -> Color {
        if transaction.hasRecategorizationSuggestion { return AppColors.warning }
        if transaction.categoryID == nil { return AppColors.expense }
        if transaction.categorizationSourceRaw == CategorizationSource.manual.rawValue { return AppColors.neutral }
        return AppColors.income
    }
}
