import SwiftUI

struct IOSAppRootView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    
    var body: some View {
        TabView {
            NavigationStack {
                IOSDashboardView()
            }
            .tabItem {
                Label(LocalizedStringKey("Dashboard"), systemImage: "chart.pie.fill")
            }

            NavigationStack {
                IOSImportView()
            }
            .tabItem {
                Label(LocalizedStringKey("Import"), systemImage: "square.and.arrow.down")
            }

            NavigationStack {
                IOSTransactionsView()
            }
            .tabItem {
                Label(LocalizedStringKey("Transactions"), systemImage: "list.bullet.rectangle.portrait")
            }

            NavigationStack {
                IOSReviewQueueView()
            }
            .tabItem {
                Label(LocalizedStringKey("Review"), systemImage: "checklist")
            }

            NavigationStack {
                IOSSettingsView()
            }
            .tabItem {
                Label(LocalizedStringKey("Settings"), systemImage: "gearshape")
            }
        }
        .tint(AppColors.accent)
        .environment(\.locale, appLanguage.locale)
    }
}
