import SwiftUI

enum IOSActivityTab: String, CaseIterable, Identifiable {
    case transactions
    case imports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transactions: return AppLanguage.currentSelection.localized("Transactions")
        case .imports: return AppLanguage.currentSelection.localized("Import")
        }
    }
}

struct IOSActivityView: View {
    @Binding var selectedTab: IOSActivityTab

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(IOSActivityTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)

            switch selectedTab {
            case .transactions:
                IOSTransactionsView()
            case .imports:
                IOSImportView()
            }
        }
        .navigationTitle(selectedTab.title)
    }
}
