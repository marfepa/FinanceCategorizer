import SwiftUI

struct IOSReviewQueueView: View {
    @Environment(\.appContainer) private var appContainer
    @State private var viewModel = ReviewQueueViewModel()
    @State private var selectedTransaction: Transaction?

    var body: some View {
        List(viewModel.transactions) { transaction in
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
                        Text(transaction.amount.privacyFormatted(hidden: false, currencyCode: transaction.currencyCode))
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
        .overlay(alignment: .bottom) {
            if let message = viewModel.recategorizationSummary ?? viewModel.statusMessage {
                Text(message)
                    .font(.footnote)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(.thinMaterial, in: Capsule())
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
        .onAppear {
            viewModel.load(using: appContainer)
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
