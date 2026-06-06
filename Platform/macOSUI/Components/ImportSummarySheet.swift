import SwiftUI

struct ImportSummarySheet: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    let summary: ImportSummary
    let onOpenTransactions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(LocalizedStringKey("Import Summary"))
                    .font(.title2.weight(.semibold))
                Text(summary.sourceFileName)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: AppSpacing.medium) {
                statCard(title: appLanguage.localized("importSummary.read"), value: appLanguage.formatInteger(summary.rawRowCount))
                statCard(title: appLanguage.localized("importSummary.valid"), value: appLanguage.formatInteger(summary.validRowCount))
                statCard(title: appLanguage.localized("importSummary.invalid"), value: appLanguage.formatInteger(summary.invalidRowCount))
                statCard(title: appLanguage.localized("importSummary.imported"), value: appLanguage.formatInteger(summary.importedCount))
                statCard(title: appLanguage.localized("importSummary.autoCategorized"), value: appLanguage.formatInteger(summary.autoCategorizedCount))
                statCard(title: appLanguage.localized("importSummary.duplicates"), value: appLanguage.formatInteger(summary.duplicatesSkipped))
                statCard(title: appLanguage.localized("Pending Review"), value: appLanguage.formatInteger(summary.pendingReviewCount))
            }

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                detailRow(title: appLanguage.localized("importSummary.detectedAccounts"), value: appLanguage.formatInteger(summary.detectedAccounts))
                detailRow(title: appLanguage.localized("importSummary.dateRange"), value: summary.dateRangeText)
            }

            HStack(spacing: AppSpacing.small) {
                PrimaryButton(title: LocalizedStringKey("importSummary.openImportedTransactions"), action: onOpenTransactions)
            }
        }
        .padding(AppSpacing.large)
        .frame(minWidth: 720)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardBackground)
        )
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
