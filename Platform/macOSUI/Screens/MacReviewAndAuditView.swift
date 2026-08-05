import SwiftUI

enum MacReviewTab: String, CaseIterable, Identifiable {
    case reviewQueue
    case audit
    case categories

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reviewQueue: return AppLanguage.currentSelection.localized("Review")
        case .audit: return AppLanguage.currentSelection.localized("audit.title")
        case .categories: return AppLanguage.currentSelection.localized("Categories")
        }
    }
}

struct MacReviewAndAuditView: View {
    @Binding var selectedTab: MacReviewTab

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(MacReviewTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.medium)
            .padding(.bottom, AppSpacing.small)

            switch selectedTab {
            case .reviewQueue:
                MacReviewQueueView()
            case .audit:
                MacCategoryAuditView()
            case .categories:
                MacCategoriesView()
            }
        }
    }
}
