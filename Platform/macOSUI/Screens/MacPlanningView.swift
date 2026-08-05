import SwiftUI

enum MacPlanningTab: String, CaseIterable, Identifiable {
    case budgets
    case goals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .budgets: return AppLanguage.currentSelection.localized("Budgets")
        case .goals: return AppLanguage.currentSelection.localized("Savings Goals")
        }
    }
}

struct MacPlanningView: View {
    @Binding var selectedTab: MacPlanningTab

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(MacPlanningTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.medium)
            .padding(.bottom, AppSpacing.small)

            switch selectedTab {
            case .budgets:
                MacBudgetsView()
            case .goals:
                MacSavingsGoalsView()
            }
        }
    }
}
