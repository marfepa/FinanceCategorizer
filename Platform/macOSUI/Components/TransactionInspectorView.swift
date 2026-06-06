import SwiftUI

struct TransactionInspectorView: View {
    @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled
    let transaction: Transaction?
    let categories: [Category]
    let selectedCategoryID: UUID?
    let selectedKind: TransactionKind
    let newCategoryName: String
    let newCategoryIsIncome: Bool
    let batchRecategorizationKind: TransactionKind
    let isRecategorizing: Bool
    let recategorizationSummary: String?
    let statusMessage: String?
    let errorMessage: String?
    let onSelectCategory: (UUID?) -> Void
    let onApplyCategory: (Bool) -> Void
    let onSelectKind: (TransactionKind) -> Void
    let onApplyKind: () -> Void
    let onNewCategoryNameChange: (String) -> Void
    let onNewCategoryIncomeChange: (Bool) -> Void
    let onCreateCategory: () -> Void
    let onBatchKindChange: (TransactionKind) -> Void
    let onRecategorizeSelectedType: () -> Void

    @State private var createRuleFromEdit = false

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(LocalizedStringKey("Inspector"))
                    .font(AppTypography.sectionTitle)

                if let transaction {
                    Group {
                        inspectorRow(title: LocalizedStringKey("Concept"), value: transaction.rawDescription)
                        inspectorRow(title: LocalizedStringKey("Merchant"), value: transaction.merchantCanonicalName ?? String(localized: "Unknown"))
                        inspectorRow(title: LocalizedStringKey("Date"), value: transaction.bookingDate.formatted(date: .complete, time: .omitted))
                        inspectorRow(title: LocalizedStringKey("Amount"), value: transaction.amount.privacyFormatted(hidden: isPrivacyModeEnabled, currencyCode: transaction.currencyCode))
                        inspectorRow(title: LocalizedStringKey("Category"), value: categoryName(for: transaction))
                        inspectorRow(title: LocalizedStringKey("Review"), value: localizedReviewStatus(transaction.reviewStatusRaw))
                        inspectorRow(title: LocalizedStringKey("Source"), value: localizedCategorizationSource(transaction.categorizationSourceRaw))
                        inspectorRow(title: LocalizedStringKey("Confidence"), value: transaction.confidence.formatted(.percent.precision(.fractionLength(0))))
                        inspectorRow(title: LocalizedStringKey("Explanation"), value: transaction.categorizationReason ?? String(localized: "No explanation available"))
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(LocalizedStringKey("Edit category"))
                            .font(.headline)

                        Picker(
                            LocalizedStringKey("Category"),
                            selection: Binding(
                                get: { selectedCategoryID },
                                set: { onSelectCategory($0) }
                            )
                        ) {
                            Text(LocalizedStringKey("Sin categorizar")).tag(UUID?.none)
                            ForEach(categories, id: \.id) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                        .labelsHidden()

                        Picker(
                            LocalizedStringKey("Movement Type"),
                            selection: Binding(
                                get: { selectedKind },
                                set: { onSelectKind($0) }
                            )
                        ) {
                            Text(LocalizedStringKey("Expense")).tag(TransactionKind.expense)
                            Text(LocalizedStringKey("Income")).tag(TransactionKind.income)
                            Text(LocalizedStringKey("Transfer")).tag(TransactionKind.transfer)
                        }
                        .labelsHidden()

                        Toggle(LocalizedStringKey("Create rule from this correction"), isOn: $createRuleFromEdit)

                        HStack {
                            Button(LocalizedStringKey("Save category")) {
                                onApplyCategory(createRuleFromEdit)
                            }
                            .appPrimaryGlassButton()
                            .disabled(selectedCategoryID == nil)

                            Button(LocalizedStringKey("Save type")) {
                                onApplyKind()
                            }
                            .appSecondaryGlassButton()

                            Button(LocalizedStringKey("Save and create rule")) {
                                createRuleFromEdit = true
                                onApplyCategory(true)
                            }
                            .appSecondaryGlassButton()
                            .disabled(selectedCategoryID == nil)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(LocalizedStringKey("Create new category"))
                                .font(.headline)

                            TextField(
                                LocalizedStringKey("Category name"),
                                text: Binding(
                                    get: { newCategoryName },
                                    set: { onNewCategoryNameChange($0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            Toggle(
                                LocalizedStringKey("Income category"),
                                isOn: Binding(
                                    get: { newCategoryIsIncome },
                                    set: { onNewCategoryIncomeChange($0) }
                                )
                            )

                            Button(LocalizedStringKey("Create category")) {
                                onCreateCategory()
                            }
                            .appSecondaryGlassButton()
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(LocalizedStringKey("Re-categorize movements"))
                                .font(.headline)

                            Picker(
                                LocalizedStringKey("Movement Type To Re-categorize"),
                                selection: Binding(
                                    get: { batchRecategorizationKind },
                                    set: { onBatchKindChange($0) }
                                )
                            ) {
                                Text(LocalizedStringKey("Expense")).tag(TransactionKind.expense)
                                Text(LocalizedStringKey("Income")).tag(TransactionKind.income)
                                Text(LocalizedStringKey("Transfer")).tag(TransactionKind.transfer)
                            }

                            Text(LocalizedStringKey("Select the movement type first. This keeps re-categorization focused while the model keeps learning from cleaner examples."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button(isRecategorizing ? String(localized: "Re-categorizing…") : String(localized: "Re-categorize selected type")) {
                                onRecategorizeSelectedType()
                            }
                            .appPrimaryGlassButton()
                            .disabled(isRecategorizing)
                        }

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }

                        if let recategorizationSummary {
                            Text(recategorizationSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    Text(LocalizedStringKey("Select a transaction to inspect its categorization state."))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(AppSpacing.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppMaterials.sidebar, in: Rectangle())
        .onChange(of: transaction?.id) { _, _ in
            createRuleFromEdit = false
        }
    }

    @ViewBuilder
    private func inspectorRow(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppTypography.body)
        }
    }

    private func categoryName(for transaction: Transaction) -> String {
        guard let categoryID = transaction.categoryID else {
            return String(localized: "Sin categorizar")
        }

        return categories.first(where: { $0.id == categoryID })?.name ?? String(localized: "Sin categorizar")
    }

    private func localizedReviewStatus(_ status: String) -> String {
        return String(localized: LocalizedStringResource(stringLiteral: status))
    }

    private func localizedCategorizationSource(_ source: String) -> String {
        return String(localized: LocalizedStringResource(stringLiteral: source))
    }
}
