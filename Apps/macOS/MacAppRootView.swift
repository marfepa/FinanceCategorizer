import SwiftUI

struct MacAppRootView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled = false
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var appLock = AppLockViewModel()
    @State private var selectedSection: MacSection? = .dashboard
    @State private var isShowingAppleAISheet = false

    @State private var dashboardTab: MacDashboardTab = .overview
    @State private var activityTab: MacActivityTab = .transactions
    @State private var reviewTab: MacReviewTab = .reviewQueue
    @State private var planningTab: MacPlanningTab = .strategy

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            if let issue = appContainer.persistenceRecoveryIssue {
                PersistenceRecoveryBanner(issue: issue)
            }

            NavigationSplitView {
            List(MacSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle(LocalizedStringKey("Finance"))
        } detail: {
            Group {
                switch selectedSection ?? .dashboard {
                case .dashboard:
                    MacDashboardContainerView(
                        selectedTab: $dashboardTab,
                        openImports: {
                            selectedSection = .activity
                            activityTab = .imports
                        },
                        openTransactions: {
                            selectedSection = .activity
                            activityTab = .transactions
                        },
                        openReview: {
                            selectedSection = .reviewAndAudit
                            reviewTab = .reviewQueue
                        },
                        openGoals: {
                            selectedSection = .planning
                            planningTab = .goals
                        }
                    )
                case .activity:
                    MacActivityView(selectedTab: $activityTab)
                case .reviewAndAudit:
                    MacReviewAndAuditView(selectedTab: $reviewTab)
                case .planning:
                    MacPlanningView(selectedTab: $planningTab)
                case .settings:
                    MacSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
            if isAppLockEnabled && appLock.isLocked {
                AppLockView(viewModel: appLock, language: appLanguage)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    isShowingAppleAISheet = true
                } label: {
                    Label(LocalizedStringKey("Apple AI"), systemImage: "sparkles")
                }
                .help(LocalizedStringKey("Open contextual Apple AI actions for the current screen"))
            }
        }
        .sheet(isPresented: $isShowingAppleAISheet) {
            AppleAIContextSheet(surface: aiSurface(for: selectedSection ?? .dashboard))
        }
        .environment(\.locale, appLanguage.locale)
        .environment(\.isPrivacyModeEnabled, isPrivacyModeEnabled)
        .onChange(of: selectedSection) { _, newValue in
            if newValue == nil {
                selectedSection = .dashboard
            }
        }
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

    private func aiSurface(for section: MacSection) -> AppleAISurface {
        switch section {
        case .dashboard:
            return dashboardTab == .overview ? .dashboard : .analysis
        case .activity:
            switch activityTab {
            case .transactions, .accounts: return .transactions
            case .imports: return .imports
            }
        case .reviewAndAudit:
            switch reviewTab {
            case .reviewQueue: return .review
            case .audit: return .review
            case .categories: return .categories
            }
        case .planning:
            return .budgets
        case .settings:
            return .settings
        }
    }
}

private enum MacSection: String, CaseIterable, Identifiable {
    case dashboard
    case activity
    case reviewAndAudit
    case planning
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: return "Dashboard"
        case .activity: return "Activity"
        case .reviewAndAudit: return "Review & Quality"
        case .planning: return "Planning"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.bar"
        case .activity: return "tablecells"
        case .reviewAndAudit: return "checklist"
        case .planning: return "target"
        case .settings: return "gearshape"
        }
    }
}
