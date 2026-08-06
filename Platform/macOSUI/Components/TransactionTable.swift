import SwiftUI

struct TransactionTable: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled
    let transactions: [Transaction]
    @Binding var searchText: String
    let selectedTransaction: Transaction?
    let onSelect: (Transaction) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            if transactions.isEmpty {
                EmptyStateView(
                    title: "No Transactions",
                    message: "Import a CSV or XLSX file to populate your desktop transaction list.",
                    systemImage: "tray"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 104)
                .padding(.horizontal, AppSpacing.large)
            } else {
                listContent
            }

            GlassSearchBar(text: $searchText, placeholder: "Buscar movimientos")
                .padding(.top, 12)
                .padding(.horizontal, AppSpacing.large)
                .zIndex(20)
                .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 8)
        }
        .background(.windowBackground)
    }

    private var listContent: some View {
        List {
            Color.clear
                .frame(height: 92)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .allowsHitTesting(false)

            ForEach(transactions) { transaction in
                Button {
                    onSelect(transaction)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                            Text(transaction.merchantDisplayName ?? transaction.rawDescription)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let merchant = transaction.merchantCanonicalName,
                               merchant != transaction.merchantDisplayName {
                                Text(merchant)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Text(appLanguage.format(date: transaction.bookingDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(transaction.amount.privacyFormatted(hidden: isPrivacyModeEnabled, language: appLanguage, currencyCode: transaction.currencyCode))
                            .foregroundStyle(transaction.amount < 0 ? .red : .green)
                    }
                    .padding(.vertical, AppSpacing.xSmall)
                    .padding(.horizontal, AppSpacing.small)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedTransaction?.id == transaction.id ? AppColors.cardBackground : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
