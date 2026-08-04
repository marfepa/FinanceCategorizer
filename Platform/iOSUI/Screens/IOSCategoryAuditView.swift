import SwiftUI

struct IOSCategoryAuditView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = CategoryAuditViewModel()
    @State private var selectedTransaction: Transaction?

    var body: some View {
        VStack(spacing: 0) {
            summary

            HStack {
                Picker(LocalizedStringKey("audit.filter.title"), selection: $viewModel.filter) {
                    ForEach(CategoryAuditFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Text(appLanguage.localized("audit.visible", appLanguage.formatInteger(viewModel.visibleTransactions.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)

            if viewModel.visibleTransactions.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("audit.empty.title"),
                    systemImage: "rectangle.and.text.magnifyingglass",
                    description: Text(LocalizedStringKey("audit.empty.message"))
                )
            } else {
                List(viewModel.visibleTransactions) { transaction in
                    Button {
                        selectedTransaction = transaction
                    } label: {
                        auditRow(transaction)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if transaction.hasRecategorizationSuggestion {
                            Button {
                                viewModel.accept(transaction, using: appContainer)
                            } label: {
                                Label(LocalizedStringKey("audit.action.accept"), systemImage: "checkmark")
                            }
                            .tint(.green)

                            Button {
                                viewModel.dismiss(transaction, using: appContainer)
                            } label: {
                                Label(LocalizedStringKey("audit.action.dismiss"), systemImage: "xmark")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(LocalizedStringKey("audit.title"))
        .searchable(text: $viewModel.searchText, prompt: Text(LocalizedStringKey("audit.search")))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await viewModel.analyzeAll(using: appContainer) }
                    } label: {
                        Label(
                            viewModel.isAnalyzing
                                ? LocalizedStringKey("audit.action.analyzing")
                                : LocalizedStringKey("audit.action.analyzeAll"),
                            systemImage: "sparkles"
                        )
                    }
                    .disabled(viewModel.isAnalyzing || viewModel.transactions.isEmpty)

                    Button {
                        viewModel.acceptAllHighConfidence(using: appContainer)
                    } label: {
                        Label(LocalizedStringKey("audit.action.acceptHighConfidence"), systemImage: "checkmark.seal")
                    }

                    Button {
                        viewModel.clearSelection()
                    } label: {
                        Label(LocalizedStringKey("audit.action.clearSelection"), systemImage: "checkmark.square")
                    }
                } label: {
                    Label(LocalizedStringKey("audit.action.more"), systemImage: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let message = viewModel.statusMessage ?? viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, AppSpacing.small)
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            IOSCategoryAuditDetailView(
                transaction: transaction,
                currentCategory: viewModel.categoryName(for: transaction.categoryID),
                suggestedCategory: transaction.suggestedCategoryID.map(viewModel.categoryName(for:)),
                confidence: viewModel.confidence(for: transaction),
                reason: viewModel.reason(for: transaction),
                onAccept: {
                    viewModel.accept(transaction, using: appContainer)
                    selectedTransaction = nil
                },
                onDismiss: {
                    viewModel.dismiss(transaction, using: appContainer)
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

    private var summary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                metric("audit.summary.analyzed", viewModel.analyzedCount, AppColors.neutral, "checklist")
                metric("audit.summary.suggestions", viewModel.suggestionCount, AppColors.warning, "sparkles")
                metric("audit.summary.uncategorized", viewModel.uncategorizedCount, AppColors.expense, "questionmark.circle")
                metric("audit.summary.lowConfidence", viewModel.lowConfidenceCount, AppColors.warning, "exclamationmark.triangle")
                metric("audit.summary.confirmed", viewModel.confirmedCount, AppColors.income, "checkmark.seal")
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
        }
        .background(.ultraThinMaterial)
    }

    private func metric(_ title: String, _ value: Int, _ tint: Color, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(appLanguage.formatInteger(value))
                .font(.headline.monospacedDigit())
            Text(LocalizedStringKey(title))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 112, alignment: .leading)
        .padding(AppSpacing.small)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
    }

    private func auditRow(_ transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            HStack(alignment: .firstTextBaseline) {
                Text(transaction.merchantDisplayName ?? transaction.rawDescription)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(transaction.amount.privacyFormatted(hidden: false, language: appLanguage, currencyCode: transaction.currencyCode))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(transaction.amount < 0 ? AppColors.expense : AppColors.income)
            }

            HStack(spacing: AppSpacing.xSmall) {
                Text(appLanguage.format(date: transaction.bookingDate, dateStyle: .short))
                Text("•")
                Text(viewModel.categoryName(for: transaction.categoryID))
                if let suggestedID = transaction.suggestedCategoryID {
                    Image(systemName: "arrow.right")
                    Text(viewModel.categoryName(for: suggestedID))
                        .foregroundStyle(AppColors.warning)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Text(LocalizedStringKey(viewModel.statusKey(for: transaction)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(transaction.hasRecategorizationSuggestion ? AppColors.warning : .secondary)
                Spacer()
                Text(appLanguage.formatPercent(viewModel.confidence(for: transaction)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}
