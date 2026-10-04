import SwiftUI

struct IOSReviewQueueView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled: Bool = false
    @State private var viewModel = ReviewQueueViewModel()
    @State private var selectedTransaction: Transaction?
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @Environment(\.undoManager) private var undoManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        List {
            if !viewModel.transferPairs.isEmpty {
                Section {
                    ForEach(viewModel.transferPairs) { proposal in
                        TransferPairRow(
                            proposal: proposal,
                            language: appLanguage,
                            isPrivacyModeEnabled: isPrivacyModeEnabled,
                            onConfirm: { viewModel.confirmTransferPair(proposal, using: appContainer) },
                            onDismiss: { viewModel.dismissTransferPair(proposal, using: appContainer) }
                        )
                    }
                } header: {
                    Text(verbatim: appLanguage.localized("review.filter.transferPairs"))
                } footer: {
                    Text(verbatim: appLanguage.localized("review.transferPair.footer"))
                }
            }

            Section {
                ForEach(viewModel.transactions) { transaction in
                    Button {
                        viewModel.select(transaction)
                        selectedTransaction = transaction
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            HStack {
                                Text(transaction.rawDescription)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Text(transaction.amount.privacyFormatted(hidden: isPrivacyModeEnabled, currencyCode: transaction.currencyCode))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(transaction.amount < 0 ? AppColors.expense : AppColors.income)
                            }

                            if let suggestedCategoryID = transaction.suggestedCategoryID,
                               let suggestedCategory = viewModel.categories.first(where: { $0.id == suggestedCategoryID }) {
                                Text("\(categoryName(for: transaction.categoryID)) → \(suggestedCategory.name)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.income)
                            } else {
                                Text(categoryName(for: transaction.categoryID))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(transaction.categorizationReason ?? String(localized: "Pending review"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if transaction.hasRecategorizationSuggestion {
                            Button {
                                viewModel.select(transaction)
                                viewModel.acceptSuggestedCategory(using: appContainer)
                            } label: {
                                Label(LocalizedStringKey("Accept"), systemImage: "checkmark")
                            }
                            .tint(AppColors.income)

                            Button {
                                viewModel.select(transaction)
                                viewModel.dismissSuggestedCategory(using: appContainer)
                            } label: {
                                Label(LocalizedStringKey("Dismiss"), systemImage: "xmark")
                            }
                            .tint(AppColors.warning)
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Review Queue"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.recategorizeAllPending(using: appContainer)
                    }
                } label: {
                    Label(
                        viewModel.isRecategorizing
                            ? LocalizedStringKey("Re-categorizing…")
                            : LocalizedStringKey("Analyze categories"),
                        systemImage: viewModel.isRecategorizing ? "hourglass" : "sparkles"
                    )
                }
                .disabled(viewModel.isRecategorizing)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let batch = viewModel.lastBatch {
                CorrectionUndoBanner(
                    batchID: batch.id,
                    message: viewModel.bannerMessage(for: batch),
                errorMessage: viewModel.errorMessage,
                    showsRuleSuggestion: batch.hasRuleSuggestion,
                    language: appLanguage,
                    onUndo: { viewModel.undoFromBanner(batch, using: appContainer) },
                    onCreateRule: { viewModel.createSuggestedRule(using: appContainer) },
                    onDismiss: { viewModel.dismissUndoBanner() }
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.lastBatch == nil,
               let message = viewModel.errorMessage ?? viewModel.recategorizationSummary ?? viewModel.statusMessage {
                Label(message, systemImage: viewModel.errorMessage == nil ? "info.circle" : "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(viewModel.errorMessage == nil ? Color.primary : AppColors.warning)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.small)
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            IOSReviewDetailView(
                transaction: transaction,
                categories: viewModel.categories,
                selectedCategoryID: Binding(
                    get: { viewModel.selectedCategoryID },
                    set: { viewModel.selectedCategoryID = $0 }
                ),
                onAcceptSuggestion: {
                    viewModel.acceptSuggestedCategory(using: appContainer)
                    selectedTransaction = nil
                },
                onApply: {
                    viewModel.approveSelected(using: appContainer)
                    selectedTransaction = nil
                },
                onDismissSuggestion: {
                    viewModel.dismissSuggestedCategory(using: appContainer)
                    selectedTransaction = nil
                }
            )
        }
        .animation(reduceMotion ? nil : .snappy, value: viewModel.lastBatch?.id)
        .onAppear {
            viewModel.undoManager = undoManager
            viewModel.load(using: appContainer)
        }
        .onChange(of: undoManager) { _, newValue in
            viewModel.undoManager = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            viewModel.load(using: appContainer)
        }
    }

    private func categoryName(for categoryID: UUID?) -> String {
        guard let categoryID,
              let category = viewModel.categories.first(where: { $0.id == categoryID }) else {
            return String(localized: "Uncategorized")
        }
        return category.name
    }
}
