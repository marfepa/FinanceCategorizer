import SwiftUI

enum MacDashboardTab: String, CaseIterable, Identifiable {
    case overview
    case analysis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return AppLanguage.currentSelection.localized("Dashboard")
        case .analysis: return AppLanguage.currentSelection.localized("Analysis")
        }
    }
}

struct MacDashboardContainerView: View {
    @Binding var selectedTab: MacDashboardTab
    let openImports: () -> Void
    let openTransactions: () -> Void
    let openReview: () -> Void
    let openGoals: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(MacDashboardTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.medium)
            .padding(.bottom, AppSpacing.small)

            switch selectedTab {
            case .overview:
                MacDashboardView(
                    openImports: openImports,
                    openTransactions: openTransactions,
                    openReview: openReview,
                    openGoals: openGoals
                )
            case .analysis:
                MacInsightsView()
            }
        }
    }
}
