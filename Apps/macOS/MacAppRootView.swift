import SwiftUI

struct MacAppRootView: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled = false
    @State private var selectedSection: MacSection? = .dashboard
    @State private var isShowingAppleAISheet = false

    var body: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle(LocalizedStringKey("Finance"))
        } detail: {
            Group {
                switch selectedSection ?? .dashboard {
                case .dashboard:
                    MacDashboardView(
                        openImports: { selectedSection = .imports },
                        openTransactions: { selectedSection = .transactions },
                        openReview: { selectedSection = .review }
                    )
                case .imports:
                    MacImportsView(openTransactions: { selectedSection = .transactions })
                case .transactions:
                    MacTransactionsView()
                case .review:
                    MacReviewQueueView()
                case .audit:
                    MacCategoryAuditView()
                case .categories:
                    MacCategoriesView()
                case .budgets:
                    MacBudgetsView()
                case .settings:
                    MacSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
    }

    private func aiSurface(for section: MacSection) -> AppleAISurface {
        switch section {
        case .dashboard:
            return .dashboard
        case .imports:
            return .imports
        case .transactions:
            return .transactions
        case .review:
            return .review
        case .audit:
            return .review
        case .categories:
            return .categories
        case .budgets:
            return .budgets
        case .settings:
            return .settings
        }
    }
}

private enum MacSection: String, CaseIterable, Identifiable {
    case dashboard
    case imports
    case transactions
    case review
    case audit
    case categories
    case budgets
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .dashboard: return "Dashboard"
        case .imports: return "Import"
        case .transactions: return "Transactions"
        case .review: return "Review"
        case .audit: return "audit.title"
        case .categories: return "Categories"
        case .budgets: return "Budgets"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.bar"
        case .imports: return "square.and.arrow.down"
        case .transactions: return "tablecells"
        case .review: return "checklist"
        case .audit: return "rectangle.and.text.magnifyingglass"
        case .categories: return "tag"
        case .budgets: return "target"
        case .settings: return "gearshape"
        }
    }
}
