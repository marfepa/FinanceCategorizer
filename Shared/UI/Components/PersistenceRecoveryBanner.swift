import SwiftUI

struct PersistenceRecoveryBanner: View {
    let issue: PersistenceRecoveryIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(LocalizedStringKey("Data recovery mode"), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text(LocalizedStringKey("The local database could not be opened. Your original files were preserved and changes made in this session will not be saved."))
                .font(.footnote)
            if let backupDirectory = issue.backupDirectory {
                Text(backupDirectory.path)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(.orange.opacity(0.18))
        .accessibilityElement(children: .combine)
    }
}
