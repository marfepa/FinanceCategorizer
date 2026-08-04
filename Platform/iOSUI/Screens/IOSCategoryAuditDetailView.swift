import SwiftUI

struct IOSCategoryAuditDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english

    let transaction: Transaction
    let currentCategory: String
    let suggestedCategory: String?
    let confidence: Double
    let reason: String
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(transaction.rawDescription)
                        .font(.headline)
                    Text(appLanguage.format(date: transaction.bookingDate, dateStyle: .long))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(transaction.amount.privacyFormatted(hidden: false, language: appLanguage, currencyCode: transaction.currencyCode))
                        .font(.title.weight(.semibold).monospacedDigit())
                        .foregroundStyle(transaction.amount < 0 ? AppColors.expense : AppColors.income)
                }

                Section(LocalizedStringKey("audit.inspector.categories")) {
                    LabeledContent(LocalizedStringKey("audit.inspector.current"), value: currentCategory)
                    LabeledContent(LocalizedStringKey("audit.inspector.suggested"), value: suggestedCategory ?? "—")
                    LabeledContent(LocalizedStringKey("audit.column.confidence"), value: appLanguage.formatPercent(confidence))
                }

                Section(LocalizedStringKey("audit.inspector.reason")) {
                    Text(reason)
                        .foregroundStyle(.secondary)
                }

                if suggestedCategory != nil {
                    Section {
                        Button {
                            onAccept()
                        } label: {
                            Label(LocalizedStringKey("audit.action.accept"), systemImage: "checkmark.circle.fill")
                        }
                        .foregroundStyle(.green)

                        Button {
                            onDismiss()
                        } label: {
                            Label(LocalizedStringKey("audit.action.dismiss"), systemImage: "xmark.circle")
                        }
                        .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("audit.inspector.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizedStringKey("Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
