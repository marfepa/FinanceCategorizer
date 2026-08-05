import SwiftUI

struct IOSAppRootView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var selectedTab: IOSTab = .dashboard
    @State private var activityTab: IOSActivityTab = .transactions
    @State private var reviewTab: IOSReviewTab = .reviewQueue

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                IOSDashboardView(
                    openImports: {
                        selectedTab = .activity
                        activityTab = .imports
                    },
                    openTransactions: {
                        selectedTab = .activity
                        activityTab = .transactions
                    },
                    openReview: {
                        selectedTab = .reviewAndAudit
                        reviewTab = .reviewQueue
                    }
                )
            }
            .tag(IOSTab.dashboard)
            .tabItem {
                Label(LocalizedStringKey("Dashboard"), systemImage: "chart.pie.fill")
            }

            NavigationStack {
                IOSActivityView(selectedTab: $activityTab)
            }
            .tag(IOSTab.activity)
            .tabItem {
                Label(LocalizedStringKey("Activity"), systemImage: "list.bullet.rectangle.portrait")
            }

            NavigationStack {
                IOSReviewAndAuditView(selectedTab: $reviewTab)
            }
            .tag(IOSTab.reviewAndAudit)
            .tabItem {
                Label(LocalizedStringKey("Review & Quality"), systemImage: "checklist")
            }

            NavigationStack {
                IOSPlanningView()
            }
            .tag(IOSTab.planning)
            .tabItem {
                Label(LocalizedStringKey("Planning"), systemImage: "target")
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
    case activity
    case reviewAndAudit
    case planning
    case settings
}
