import SwiftUI

struct IOSReviewDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled: Bool = false

    let transaction: Transaction
    let categories: [Category]
    @Binding var selectedCategoryID: UUID?
    let onAcceptSuggestion: () -> Void
    let onApply: () -> Void
    let onDismissSuggestion: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("Movement")) {
                    LabeledContent(LocalizedStringKey("Concept"), value: transaction.rawDescription)
                    LabeledContent(LocalizedStringKey("Amount"), value: transaction.amount.privacyFormatted(hidden: isPrivacyModeEnabled, currencyCode: transaction.currencyCode))
                    LabeledContent(LocalizedStringKey("Date"), value: transaction.bookingDate.formatted(date: .abbreviated, time: .omitted))
                }

                Section(LocalizedStringKey("Category")) {
                    Picker(LocalizedStringKey("Assign Category"), selection: $selectedCategoryID) {
                        Text(LocalizedStringKey("Uncategorized")).tag(UUID?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }

                    if let suggestedCategoryID = transaction.suggestedCategoryID,
                       let suggestedCategory = categories.first(where: { $0.id == suggestedCategoryID }) {
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text(LocalizedStringKey("Suggested Category"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(suggestedCategory.name) · \((transaction.suggestedConfidence ?? 0).formatted(.percent.precision(.fractionLength(0))))")
                                .foregroundStyle(.green)
                            if let reason = transaction.suggestedReason {
                                Text(reason)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(LocalizedStringKey("Accept Category Suggestion"), action: onAcceptSuggestion)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Review Movement"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Save"), action: onApply)
                        .disabled(selectedCategoryID == nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if transaction.hasRecategorizationSuggestion {
                    Button(LocalizedStringKey("Dismiss Category Suggestion"), action: onDismissSuggestion)
                        .font(.footnote)
                        .padding(.bottom, AppSpacing.small)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
