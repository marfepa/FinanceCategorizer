import SwiftUI

struct CategoryChartFilterControl: View {
    let availableCategories: [String]
    @Binding var selectedCategory: String?
    var appLanguage: AppLanguage = .spanish

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            // Segmented pill container for quick categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // All categories chip
                    let isAllSelected = selectedCategory == nil
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.80)) {
                            selectedCategory = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(allCategoriesTitle)
                                .font(.caption2.weight(isAllSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            isAllSelected ? AppColors.neutral.opacity(0.85) : Color.white.opacity(0.06),
                            in: Capsule()
                        )
                        .foregroundStyle(isAllSelected ? .white : .primary.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    // Individual category chips
                    ForEach(availableCategories, id: \.self) { categoryName in
                        let isSelected = selectedCategory == categoryName
                        Button {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.80)) {
                                if isSelected {
                                    selectedCategory = nil
                                } else {
                                    selectedCategory = categoryName
                                }
                            }
                        } label: {
                            Text(categoryName)
                                .font(.caption2.weight(isSelected ? .bold : .regular))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    isSelected ? AppColors.income.opacity(0.90) : Color.white.opacity(0.06),
                                    in: Capsule()
                                )
                                .foregroundStyle(isSelected ? .white : .primary.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                )
            }

            Spacer(minLength: 4)

            // Dropdown menu for picking any category (including minor/low-expense ones)
            Menu {
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.80)) {
                        selectedCategory = nil
                    }
                } label: {
                    HStack {
                        Text(allCategoriesTitle)
                        if selectedCategory == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(availableCategories, id: \.self) { categoryName in
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.80)) {
                            selectedCategory = categoryName
                        }
                    } label: {
                        HStack {
                            Text(categoryName)
                            if selectedCategory == categoryName {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.caption2.weight(.semibold))
                    Text(selectedCategory ?? filterTitle)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    selectedCategory != nil ? AppColors.income.opacity(0.16) : Color.white.opacity(0.08),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(selectedCategory != nil ? AppColors.income.opacity(0.40) : Color.white.opacity(0.14), lineWidth: 0.8)
                )
                .foregroundStyle(.primary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if selectedCategory != nil {
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.80)) {
                        selectedCategory = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(appLanguage == .spanish ? "Limpiar filtro" : "Clear filter")
            }
        }
    }

    private var allCategoriesTitle: String {
        appLanguage == .spanish ? "Todas" : "All"
    }

    private var filterTitle: String {
        appLanguage == .spanish ? "Filtrar..." : "Filter..."
    }
}
