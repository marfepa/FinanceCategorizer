import SwiftUI

enum IOSReviewTab: String, CaseIterable, Identifiable {
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

struct IOSReviewAndAuditView: View {
    @Binding var selectedTab: IOSReviewTab
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(IOSReviewTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)

            switch selectedTab {
            case .reviewQueue:
                IOSReviewQueueView()
            case .audit:
                IOSCategoryAuditView()
            case .categories:
                IOSCategoriesView()
            }
        }
        .navigationTitle(selectedTab.title)
    }
}
