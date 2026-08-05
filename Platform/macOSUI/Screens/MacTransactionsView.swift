import SwiftUI
import OSLog

private let transactionsLogger = Logger(subsystem: "com.mariofernandez.FinanceCategorizer", category: "transactions")

struct MacTransactionsView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled = false
    @State private var viewModel = TransactionsViewModel()

    @State private var isExporting = false
    @State private var exportDocument: CSVDocument?

    var body: some View {
        VStack(spacing: 0) {
            filterBar
                .padding()
                .background(.windowBackground)

            DuplicateReviewPanel(
                groups: viewModel.duplicateGroups,
                transactions: viewModel.transactions,
                isScanning: viewModel.isScanningDuplicates,
                onScan: {
                    viewModel.scanDuplicates(using: appContainer, language: .currentSelection)
                },
                onDismiss: { group in
                    viewModel.dismissDuplicateGroup(group, using: appContainer, language: .currentSelection)
                },
                onRemove: { group in
                    viewModel.removeDuplicateGroup(group, using: appContainer, language: .currentSelection)
                },
                onResolveAll: { groups in
                    viewModel.resolveAllDuplicateGroups(groups, using: appContainer, language: .currentSelection)
                }
            )
            .padding(.horizontal)
            .padding(.bottom, AppSpacing.small)
            
            Divider()

            HSplitView {
                TransactionTable(
                    transactions: viewModel.sortedTransactions,
                    searchText: $viewModel.searchText,
                    selectedTransaction: viewModel.selectedTransaction,
                    onSelect: { transaction in
                        viewModel.select(transaction)
                    }
                )
                TransactionInspectorView(
                    transaction: viewModel.selectedTransaction,
                    categories: viewModel.categories,
                    selectedCategoryID: viewModel.selectedCategoryID,
                    selectedKind: viewModel.selectedKind,
                    newCategoryName: viewModel.newCategoryName,
                    newCategoryIsIncome: viewModel.newCategoryIsIncome,
                    batchRecategorizationKind: viewModel.batchRecategorizationKind,
                    isRecategorizing: viewModel.isRecategorizing,
                    recategorizationSummary: viewModel.recategorizationSummary,
                    statusMessage: viewModel.statusMessage,
                    errorMessage: viewModel.errorMessage,
                    onSelectCategory: { categoryID in
                        viewModel.setSelectedCategory(categoryID)
                    },
                    onApplyCategory: { createRule in
                        viewModel.applyCategoryEdit(using: appContainer, createRule: createRule)
                    },
                    onSelectKind: { kind in
                        viewModel.selectedKind = kind
                    },
                    onApplyKind: {
                        viewModel.applyKindEdit(using: appContainer)
                    },
                    onNewCategoryNameChange: { name in
                        viewModel.newCategoryName = name
                    },
                    onNewCategoryIncomeChange: { isIncome in
                        viewModel.newCategoryIsIncome = isIncome
                    },
                    onCreateCategory: {
                        viewModel.createCategory(using: appContainer)
                    },
                    onBatchKindChange: { kind in
                        viewModel.batchRecategorizationKind = kind
                    },
                    onRecategorizeSelectedType: {
                        Task {
                            await viewModel.recategorizeSelectedType(using: appContainer)
                        }
                    }
                )
                .frame(minWidth: 260, idealWidth: 320)
            }
        }
        .navigationTitle(LocalizedStringKey("Transactions"))
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "Transactions_Export_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        ) { result in
            switch result {
            case .success(let url):
                transactionsLogger.info("Exported transactions to \(url.path, privacy: .private)")
            case .failure(let error):
                transactionsLogger.error("Transaction export failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        .onAppear {
            viewModel.load(using: appContainer)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            viewModel.load(using: appContainer)
        }
    }

    private var filterBar: some View {
        HStack(spacing: AppSpacing.large) {
            // Filters
            HStack(spacing: AppSpacing.medium) {
                Picker(LocalizedStringKey("Type"), selection: $viewModel.filterKind) {
                    Text(LocalizedStringKey("All Types")).tag(TransactionKind?.none)
                    Text(LocalizedStringKey("Income")).tag(Optional(TransactionKind.income))
                    Text(LocalizedStringKey("Expense")).tag(Optional(TransactionKind.expense))
                    Text(LocalizedStringKey("Transfer")).tag(Optional(TransactionKind.transfer))
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                Picker(LocalizedStringKey("Category"), selection: $viewModel.filterCategoryID) {
                    Text(LocalizedStringKey("All Categories")).tag(UUID?.none)
                    Divider()
                    ForEach(viewModel.categories, id: \.id) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)

                Picker(LocalizedStringKey("Sort"), selection: $viewModel.transactionDateSortOrder) {
                    Text(LocalizedStringKey("Newest First")).tag(TransactionsViewModel.TransactionDateSortOrder.newestFirst)
                    Text(LocalizedStringKey("Oldest First")).tag(TransactionsViewModel.TransactionDateSortOrder.oldestFirst)
                }
                .pickerStyle(.menu)
                .frame(width: 160)
                
                Button(LocalizedStringKey("Clear")) {
                    viewModel.filterKind = nil
                    viewModel.filterCategoryID = nil
                    viewModel.filterStartDate = nil
                    viewModel.filterEndDate = nil
                    viewModel.transactionDateSortOrder = .newestFirst
                }
                .disabled(viewModel.filterKind == nil && viewModel.filterCategoryID == nil && viewModel.filterStartDate == nil && viewModel.filterEndDate == nil && viewModel.transactionDateSortOrder == .newestFirst)
                
                Button {
                    let csv = ExportService.generateCSV(from: viewModel.sortedTransactions, categories: viewModel.categories)
                    exportDocument = CSVDocument(text: csv)
                    isExporting = true
                } label: {
                    Label(LocalizedStringKey("Export CSV"), systemImage: "arrow.down.doc")
                }
                .disabled(viewModel.sortedTransactions.isEmpty)
            }

            Spacer()

            // KPIs
            HStack(spacing: AppSpacing.medium) {
                kpiView(title: LocalizedStringKey("Income"), value: viewModel.filteredIncome, color: AppColors.income)
                kpiView(title: LocalizedStringKey("Expense"), value: viewModel.filteredExpense, color: AppColors.expense)
                kpiView(title: LocalizedStringKey("Found"), value: Decimal(viewModel.filteredCount), color: .primary, isCount: true)
            }
        }
    }

    private func kpiView(title: LocalizedStringKey, value: Decimal, color: Color, isCount: Bool = false) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if isCount {
                Text("\(NSDecimalNumber(decimal: value).intValue)")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color)
            } else {
                Text(value.privacyFormatted(hidden: isPrivacyModeEnabled))
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(color)
            }
        }
    }
}
