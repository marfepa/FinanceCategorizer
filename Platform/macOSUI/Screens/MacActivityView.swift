import SwiftUI

enum MacActivityTab: String, CaseIterable, Identifiable {
    case transactions
    case accounts
    case imports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transactions: return AppLanguage.currentSelection.localized("Transactions")
        case .accounts: return AppLanguage.currentSelection.localized("Accounts")
        case .imports: return AppLanguage.currentSelection.localized("Import")
        }
    }
}

struct MacActivityView: View {
    @Binding var selectedTab: MacActivityTab

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(MacActivityTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.medium)
            .padding(.bottom, AppSpacing.small)

            switch selectedTab {
            case .transactions:
                MacTransactionsView()
            case .accounts:
                AccountsView()
            case .imports:
                MacImportsView(openTransactions: { selectedTab = .transactions })
            }
        }
    }
}
