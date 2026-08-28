import SwiftUI
import UniformTypeIdentifiers

struct IOSImportView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = ImportViewModel()
    @State private var isFileImporterPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(LocalizedStringKey("Import Bank Transactions"))
                        .font(AppTypography.screenTitle)
                    Text(LocalizedStringKey("Choose a CSV, XLSX, or PDF export from your bank, or paste CSV text below."))
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isFileImporterPresented = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey("Choose File"))
                                .font(.headline)
                            if let selectedURL = viewModel.selectedFileURL {
                                Text(selectedURL.lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(LocalizedStringKey("CSV, XLSX, or PDF"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(AppSpacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardBackground)
                    )
                }
                .buttonStyle(.plain)

                TextField(LocalizedStringKey("Source file name"), text: $viewModel.sourceFileName)
                    .textFieldStyle(.roundedBorder)

                TextField(LocalizedStringKey("Account name, for example Main account"), text: $viewModel.accountName)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(LocalizedStringKey("Or paste CSV text directly"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $viewModel.csvText)
                        .scrollDisabled(true)
                        .frame(minHeight: 160)
                        .padding(AppSpacing.small)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.cardBackground)
                        )
                }

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
                        ProgressView(value: viewModel.importProgress, total: 1)
                            .frame(maxWidth: 120)
                            .padding(.leading, AppSpacing.small)
                        Button(LocalizedStringKey("Cancel"), role: .cancel) {
                            viewModel.cancelImport()
                        }
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
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .spreadsheet, .pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                viewModel.selectedFileURL = url
                viewModel.sourceFileName = url.lastPathComponent
                viewModel.preview(using: appContainer, language: appLanguage)
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }
}
