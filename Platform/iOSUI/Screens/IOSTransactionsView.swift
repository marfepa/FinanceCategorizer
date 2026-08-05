import SwiftUI

struct IOSTransactionsView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = TransactionsViewModel()

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

                        if let recategorizationSummary = viewModel.recategorizationSummary {
                            Text(recategorizationSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let statusMessage = viewModel.statusMessage {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
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
                                    .foregroundStyle(NSDecimalNumber(decimal: transaction.amount).doubleValue < 0 ? .red : .green)
                            }
                            .padding(.vertical, AppSpacing.xSmall)
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
        .onAppear {
            viewModel.load(using: appContainer)
        }
    }
}
