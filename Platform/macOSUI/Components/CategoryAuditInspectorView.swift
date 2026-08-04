import SwiftUI

struct CategoryAuditInspectorView: View {
    @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english

    let transaction: Transaction?
    let viewModel: CategoryAuditViewModel
    let onAccept: (Transaction) -> Void
    let onDismiss: (Transaction) -> Void
    let onAssign: (Transaction, UUID) -> Void

    @State private var isChoosingCategory = false

    var body: some View {
        Group {
            if let transaction {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(transaction.rawDescription)
                                .font(AppTypography.sectionTitle)
                                .lineLimit(3)
                            Text(transaction.bookingDate.formatted(date: .complete, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(transaction.amount.privacyFormatted(
                                hidden: isPrivacyModeEnabled,
                                language: appLanguage,
                                currencyCode: transaction.currencyCode
                            ))
                            .font(AppTypography.heroNumber)
                            .foregroundStyle(transaction.amount < 0 ? AppColors.expense : AppColors.income)
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            auditValue(
                                title: LocalizedStringKey("audit.inspector.current"),
                                value: viewModel.categoryName(for: transaction.categoryID)
                            )
                            auditValue(
                                title: LocalizedStringKey("audit.inspector.suggested"),
                                value: transaction.suggestedCategoryID.map(viewModel.categoryName(for:)) ?? "—"
                            )
                            auditValue(
                                title: LocalizedStringKey("audit.column.confidence"),
                                value: appLanguage.formatPercent(viewModel.confidence(for: transaction))
                            )
                            auditValue(
                                title: LocalizedStringKey("audit.column.status"),
                                value: appLanguage.localized(viewModel.statusKey(for: transaction))
                            )
                        }
                        .padding(AppSpacing.medium)
                        .background(AppMaterials.groupedGlass, in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))

                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(LocalizedStringKey("audit.inspector.reason"))
                                .font(AppTypography.sectionTitle)
                            Text(viewModel.reason(for: transaction))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Button {
                                withAnimation(.snappy) {
                                    isChoosingCategory.toggle()
                                }
                            } label: {
                                Label(
                                    LocalizedStringKey(
                                        transaction.hasRecategorizationSuggestion
                                            ? "audit.action.chooseDifferentCategory"
                                            : "audit.action.changeCategory"
                                    ),
                                    systemImage: isChoosingCategory ? "chevron.up" : "tag"
                                )
                            }
                            .buttonStyle(.bordered)

                            if isChoosingCategory {
                                CategoryOverridePicker(
                                    categories: viewModel.categories,
                                    selectedCategoryID: transaction.suggestedCategoryID ?? transaction.categoryID,
                                    onSelect: { categoryID in
                                        onAssign(transaction, categoryID)
                                        isChoosingCategory = false
                                    }
                                )
                            }
                        }

                        if transaction.hasRecategorizationSuggestion {
                            HStack(spacing: AppSpacing.small) {
                                Button {
                                    onAccept(transaction)
                                } label: {
                                    Label(LocalizedStringKey("audit.action.accept"), systemImage: "checkmark.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    onDismiss(transaction)
                                } label: {
                                    Label(LocalizedStringKey("audit.action.dismiss"), systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(AppLayoutMetrics.sectionGap)
                }
            } else {
                ContentUnavailableView(
                    LocalizedStringKey("audit.inspector.emptyTitle"),
                    systemImage: "rectangle.and.text.magnifyingglass",
                    description: Text(LocalizedStringKey("audit.inspector.emptyMessage"))
                )
            }
        }
        .background(AppMaterials.contentMaterial)
    }

    private func auditValue(title: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: AppSpacing.small)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}
