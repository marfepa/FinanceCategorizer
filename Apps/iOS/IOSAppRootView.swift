import SwiftUI

struct IOSAppRootView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var selectedTab: IOSTab = .dashboard
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                IOSDashboardView(
                    openImports: { selectedTab = .imports },
                    openTransactions: { selectedTab = .transactions },
                    openReview: { selectedTab = .review }
                )
            }
            .tag(IOSTab.dashboard)
            .tabItem {
                Label(LocalizedStringKey("Dashboard"), systemImage: "chart.pie.fill")
            }

            NavigationStack {
                IOSImportView()
            }
            .tag(IOSTab.imports)
            .tabItem {
                Label(LocalizedStringKey("Import"), systemImage: "square.and.arrow.down")
            }

            NavigationStack {
                IOSTransactionsView()
            }
            .tag(IOSTab.transactions)
            .tabItem {
                Label(LocalizedStringKey("Transactions"), systemImage: "list.bullet.rectangle.portrait")
            }

            NavigationStack {
                IOSReviewQueueView()
            }
            .tag(IOSTab.review)
            .tabItem {
                Label(LocalizedStringKey("Review"), systemImage: "checklist")
            }

            NavigationStack {
                IOSCategoryAuditView()
            }
            .tag(IOSTab.audit)
            .tabItem {
                Label(LocalizedStringKey("audit.title"), systemImage: "rectangle.and.text.magnifyingglass")
            }

            NavigationStack {
                IOSSettingsView()
            }
            .tag(IOSTab.settings)
            .tabItem {
                Label(LocalizedStringKey("Settings"), systemImage: "gearshape")
            }
        }
        .tint(AppColors.accent)
        .environment(\.locale, appLanguage.locale)
    }
}

private enum IOSTab: Hashable {
    case dashboard
    case imports
    case transactions
    case review
    case audit
    case settings
}
