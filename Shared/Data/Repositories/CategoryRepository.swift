import Foundation
import SwiftData

@MainActor
final class CategoryRepository {
    private let modelContainer: ModelContainer

    private let baseCategories: [(name: String, icon: String, color: String, isIncome: Bool)] = [
        ("Alimentacion", "cart", "#4CAF50", false),
        ("Restauracion", "fork.knife", "#FF7043", false),
        ("Compras", "bag", "#7E57C2", false),
        ("Transporte", "car", "#1E88E5", false),
        ("Hogar", "house", "#8D6E63", false),
        ("Suministros", "bolt", "#FBC02D", false),
        ("Suscripciones", "repeat", "#5C6BC0", false),
        ("Salud", "cross.case", "#EF5350", false),
        ("Cuidado personal", "scissors", "#EC407A", false),
        ("Deportes", "figure.run", "#00897B", false),
        ("Donaciones", "heart", "#D81B60", false),
        ("Ocio", "gamecontroller", "#AB47BC", false),
        ("Viajes", "airplane", "#26A69A", false),
        ("Educacion", "book", "#42A5F5", false),
        ("Finanzas", "creditcard", "#78909C", false),
        ("Impuestos", "building.columns", "#8E24AA", false),
        ("Efectivo", "banknote", "#607D8B", false),
        ("Ingresos", "arrow.down.circle", "#2E7D32", true),
        ("Transferencias", "arrow.left.arrow.right", "#546E7A", false),
        ("Sin categorizar", "questionmark.circle", "#9E9E9E", false)
    ]

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func fetchAll() throws -> [Category] {
        let context = makeContext()
        return try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]))
    }

    func fetch(categoryID: UUID) throws -> Category? {
        let context = makeContext()
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == categoryID })
        return try context.fetch(descriptor).first
    }

    func ensureBaseCategories() throws {
        let context = makeContext()
        let count = try context.fetchCount(FetchDescriptor<Category>())
        if count >= baseCategories.count {
            return
        }
        let existing = try context.fetch(FetchDescriptor<Category>())
        let existingNames = Set(existing.map(\.name))

        for (index, category) in baseCategories.enumerated() where !existingNames.contains(category.name) {
            context.insert(
                Category(
                    name: category.name,
                    iconName: category.icon,
                    colorHex: category.color,
                    parentID: nil,
                    isIncome: category.isIncome,
                    sortOrder: index,
                    isSystem: true
                )
            )
        }

        if context.hasChanges {
            try context.save()
        }
    }

    func fetchOrCreateBaseCategory(named name: String, isIncome: Bool) throws -> Category {
        try ensureBaseCategories()

        let context = makeContext()
        let categories = try context.fetch(FetchDescriptor<Category>())
        if let existing = categories.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }

        let category = Category(
            name: name,
            iconName: isIncome ? "arrow.down.circle" : "tag",
            colorHex: isIncome ? "#2E7D32" : "#607D8B",
            parentID: nil,
            isIncome: isIncome,
            sortOrder: categories.count,
            isSystem: false
        )
        context.insert(category)
        try context.save()
        return category
    }
}
