import SwiftUI

struct ExportAuditHistoryView: View {
    let language: AppLanguage
    @State private var entries: [ExportAuditEntry] = []

    var body: some View {
        Group {
            if entries.isEmpty {
                Text(LocalizedStringKey("No exports recorded"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entries.prefix(5).enumerated()), id: \.offset) { _, entry in
                    LabeledContent {
                        Text(language.localized(
                            entry.privacyMode == .anonymized ? "Anonymized" : "Full"
                        ))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language.format(date: entry.exportedAt, dateStyle: .medium, timeStyle: .short))
                            Text(language.localized(
                                "%lld movements",
                                entry.transactionCount
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Button(LocalizedStringKey("Clear export history"), role: .destructive) {
                    ExportAuditService().clear()
                    entries = []
                }
            }
        }
        .onAppear {
            entries = ExportAuditService().entries()
        }
    }
}
