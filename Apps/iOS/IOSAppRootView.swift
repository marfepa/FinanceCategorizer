import SwiftUI

struct IOSAppRootView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled = false
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var appLock = AppLockViewModel()
    @State private var selectedTab: IOSTab = .dashboard
    @State private var activityTab: IOSActivityTab = .transactions
    @State private var reviewTab: IOSReviewTab = .reviewQueue

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            if let issue = appContainer.persistenceRecoveryIssue {
                PersistenceRecoveryBanner(issue: issue)
            }

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
        }
            if isAppLockEnabled && appLock.isLocked {
                AppLockView(viewModel: appLock, language: appLanguage)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .tint(AppColors.accent)
        .environment(\.locale, appLanguage.locale)
        .environment(\.isPrivacyModeEnabled, isPrivacyModeEnabled)
        .task(id: isAppLockEnabled) {
            await appLock.configure(isEnabled: isAppLockEnabled, reason: appLanguage.localized("appLock.reason"))
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive, .background:
                appLock.lockIfEnabled(isAppLockEnabled)
            case .active:
                Task { await appLock.authenticate(reason: appLanguage.localized("appLock.reason")) }
            @unknown default:
                break
            }
        }
    }
}

private enum IOSTab: Hashable {
    case dashboard
    case activity
    case reviewAndAudit
    case planning
    case settings
}
