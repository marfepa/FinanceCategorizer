import SwiftUI

struct IOSTransactionsView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = TransactionsViewModel()
    @State private var isShowingExportOptions = false
    @State private var isExporting = false
    @State private var exportDocument: CSVDocument?
    @State private var pendingExportMode: ExportService.PrivacyMode = .full
    @State private var pendingExportCount = 0

    var body: some View {
        Group {
            if viewModel.transactions.isEmpty {
                EmptyStateView(
                    title: "No Transactions Yet",
                    message: "Import a CSV from the Import tab and your transactions will appear here.",
                    systemImage: "list.bullet.rectangle"
                )
            } else {
                List {
                    Section(LocalizedStringKey("Actions")) {
                        Picker(LocalizedStringKey("Type to re-categorize"), selection: $viewModel.batchRecategorizationKind) {
                            Text(LocalizedStringKey("Expense")).tag(TransactionKind.expense)
                            Text(LocalizedStringKey("Income")).tag(TransactionKind.income)
                            Text(LocalizedStringKey("Transfer")).tag(TransactionKind.transfer)
                        }

                        Button(viewModel.isRecategorizing ? appLanguage.localized("transactions.recategorizing") : appLanguage.localized("transactions.recategorizeSelectedType")) {
                            Task {
                                await viewModel.recategorizeSelectedType(using: appContainer)
                            }
                        }
                        .disabled(viewModel.isRecategorizing)

                        TextField(LocalizedStringKey("New category"), text: $viewModel.newCategoryName)
                        Toggle(LocalizedStringKey("Income category"), isOn: $viewModel.newCategoryIsIncome)

                        Button(LocalizedStringKey("Create category")) {
                            viewModel.createCategory(using: appContainer)
                        }
                        .disabled(viewModel.newCategoryName.isEmpty)

                        if let recategorizationSummary = viewModel.recategorizationSummary {
                            Text(recategorizationSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let statusMessage = viewModel.statusMessage {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(AppColors.income)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(AppColors.expense)
                        }
                    }

                    Section {
                        DuplicateReviewPanel(
                            groups: viewModel.duplicateGroups,
                            transactions: viewModel.transactions,
                            isScanning: viewModel.isScanningDuplicates,
                            onScan: {
                                viewModel.scanDuplicates(using: appContainer, language: appLanguage)
                            },
                            onDismiss: { group in
                                viewModel.dismissDuplicateGroup(group, using: appContainer, language: appLanguage)
                            },
                            onRemove: { group in
                                viewModel.removeDuplicateGroup(group, using: appContainer, language: appLanguage)
                            },
                            onResolveAll: { groups in
                                viewModel.resolveAllDuplicateGroups(groups, using: appContainer, language: appLanguage)
                            }
                        )
                    } header: {
                        Text(LocalizedStringKey("duplicate.title"))
                    }

                    Section(LocalizedStringKey("Movements")) {
                        ForEach(viewModel.filteredTransactions) { transaction in
                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text(transaction.rawDescription)
                                    .font(.headline)
                                Text(appLanguage.format(date: transaction.bookingDate))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(appLanguage.formatCurrency(transaction.amount, code: transaction.currencyCode))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(transaction.amount < 0 ? AppColors.expense : AppColors.income)
                            }
                            .padding(.vertical, AppSpacing.xSmall)
                        }

                        if viewModel.hasMoreTransactions {
                            Button {
                                viewModel.loadMore(using: appContainer)
                            } label: {
                                HStack {
                                    Spacer()
                                    if viewModel.isLoadingMore {
                                        ProgressView()
                                    } else {
                                        Text(LocalizedStringKey("Load more movements"))
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(viewModel.isLoadingMore)
                        }
                    }
                }
                .searchable(text: $viewModel.searchText, prompt: LocalizedStringKey("Search concepts"))
                .refreshable {
                    viewModel.load(using: appContainer)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Transactions"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingExportOptions = true
                } label: {
                    Label(LocalizedStringKey("Export CSV"), systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.sortedTransactions.isEmpty)
            }
        }
        .confirmationDialog(
            LocalizedStringKey("Choose export privacy"),
            isPresented: $isShowingExportOptions,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("Export anonymized CSV")) {
                prepareExport(privacyMode: .anonymized)
            }
            Button(LocalizedStringKey("Export full CSV"), role: .destructive) {
                prepareExport(privacyMode: .full)
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("Exported files leave the app's private storage. Anonymized export removes concepts and merchant names."))
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "Transactions_Export_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        ) { result in
            if case .success = result {
                ExportAuditService().record(
                    privacyMode: pendingExportMode,
                    transactionCount: pendingExportCount
                )
            }
        }
        .onAppear {
            viewModel.load(using: appContainer)
        }
        .onChange(of: viewModel.searchText) { _, query in
            if !query.isEmpty {
                viewModel.ensureCompleteHistoryLoaded(using: appContainer)
            }
        }
    }

    private func prepareExport(privacyMode: ExportService.PrivacyMode) {
        let exportedTransactions = viewModel.sortedTransactions
        pendingExportMode = privacyMode
        pendingExportCount = exportedTransactions.count
        exportDocument = CSVDocument(text: ExportService.generateCSV(
            from: exportedTransactions,
            categories: viewModel.categories,
            privacyMode: privacyMode
        ))
        isExporting = true
    }
}
