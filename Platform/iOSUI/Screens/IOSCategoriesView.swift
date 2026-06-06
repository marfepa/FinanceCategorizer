import SwiftUI

struct IOSCategoriesView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = CategoriesViewModel()

    var body: some View {
        List(viewModel.categories) { category in
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(category.name)
                Text(appLanguage.localized("categories.groupCount", category.group, appLanguage.formatInteger(category.transactionCount)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(LocalizedStringKey("Categories"))
        .onAppear {
            viewModel.load(using: appContainer)
        }
    }
}
