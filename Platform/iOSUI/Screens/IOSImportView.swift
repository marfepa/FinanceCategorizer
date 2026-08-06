import SwiftUI

struct IOSImportView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = ImportViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(LocalizedStringKey("Paste CSV"))
                        .font(AppTypography.screenTitle)
                    Text(LocalizedStringKey("Expected header: date, concept, amount"))
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                }

                TextField(LocalizedStringKey("Source file name"), text: $viewModel.sourceFileName)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $viewModel.csvText)
                    .scrollDisabled(true)
                    .frame(minHeight: 220)
                    .padding(AppSpacing.small)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardBackground)
                    )

                HStack(spacing: AppSpacing.small) {
                    PrimaryButton(title: LocalizedStringKey("Preview")) {
                        viewModel.preview(using: appContainer, language: appLanguage)
                    }

                    PrimaryButton(title: LocalizedStringKey("Import")) {
                        Task {
                            await viewModel.importTransactions(using: appContainer, language: appLanguage)
                        }
                    }
                    .disabled(viewModel.isImporting)
                    
                    if viewModel.isImporting {
                        ProgressView()
                            .padding(.leading, AppSpacing.small)
                    }
                }

                if let statusMessage = viewModel.statusMessage {
                    Text(statusMessage)
                        .foregroundStyle(.green)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if !viewModel.previewRows.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(LocalizedStringKey("Preview"))
                            .font(AppTypography.sectionTitle)

                        ForEach(viewModel.previewRows) { row in
                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text(row.concept)
                                    .font(.headline)
                                Text("\(appLanguage.format(date: row.bookingDate)) • \(appLanguage.formatCurrency(row.amount, code: row.currencyCode ?? "EUR"))")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.cardBackground)
                            )
                        }
                    }
                }
            }
            .padding(AppSpacing.large)
        }
        .navigationTitle(LocalizedStringKey("Import"))
    }
}
