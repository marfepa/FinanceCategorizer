import SwiftUI

struct RecentImportsList: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    let sessions: [ImportBatch]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(LocalizedStringKey("Recent Imports"))
                .font(AppTypography.sectionTitle)

            if sessions.isEmpty {
                Text(LocalizedStringKey("No imports yet."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text(session.fileName)
                            Text(appLanguage.format(date: session.importedAt, dateStyle: .medium, timeStyle: .short))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(appLanguage.localized("recentImports.rows", appLanguage.formatInteger(session.importedRowCount)))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, AppSpacing.xSmall)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
