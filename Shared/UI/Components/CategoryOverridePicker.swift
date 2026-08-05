import SwiftUI

struct CategoryOverridePicker: View {
    @State private var searchText = ""

    let categories: [Category]
    let selectedCategoryID: UUID?
    let onSelect: (UUID) -> Void

    private var filteredCategories: [Category] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return categories }
        return categories.filter { category in
            category.name.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            TextField(
                LocalizedStringKey("audit.category.search"),
                text: $searchText
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(LocalizedStringKey("audit.category.search"))

            if filteredCategories.isEmpty {
                Text(LocalizedStringKey("audit.category.noneFound"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.small)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredCategories) { category in
                            Button {
                                onSelect(category.id)
                            } label: {
                                HStack(spacing: AppSpacing.small) {
                                    Image(systemName: category.iconName)
                                        .frame(width: 20)
                                        .foregroundStyle(.secondary)
                                    Text(category.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedCategoryID == category.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppColors.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 6)
                                .padding(.horizontal, AppSpacing.xSmall)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(category.name)
                            .accessibilityAddTraits(selectedCategoryID == category.id ? .isSelected : [])
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(AppSpacing.small)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
    }
}
