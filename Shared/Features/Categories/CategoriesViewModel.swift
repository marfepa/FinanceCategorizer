import Foundation
import Observation

struct CategoryListItem: Identifiable {
    let id: UUID
    let name: String
    let group: String
    let transactionCount: Int
    let activityShare: Double
    let isSystem: Bool
}

@MainActor
@Observable
final class CategoriesViewModel {
    var categoryCount = 0
    var categories: [CategoryListItem] = []
    var errorMessage: String?

    func load(using container: AppContainer) {
        do {
            try container.categoryRepository.ensureBaseCategories()
            let categories = try container.categoryRepository.fetchAll()
            let transactions = try container.transactionRepository.fetchAll()
            let counts = Dictionary(grouping: transactions, by: \.categoryID)
                .mapValues(\.count)
            let categorizedMovementCount = transactions.count(where: { $0.categoryID != nil })

            self.categories = categories.map { category in
                let transactionCount = counts[category.id] ?? 0
                return CategoryListItem(
                    id: category.id,
                    name: category.name,
                    group: category.isIncome ? "Income" : (category.parentID == nil ? "Primary" : "Subcategory"),
                    transactionCount: transactionCount,
                    activityShare: categorizedMovementCount == 0
                        ? 0
                        : Double(transactionCount) / Double(categorizedMovementCount),
                    isSystem: category.isSystem
                )
            }
            .sorted { $0.name < $1.name }

            categoryCount = self.categories.count
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
