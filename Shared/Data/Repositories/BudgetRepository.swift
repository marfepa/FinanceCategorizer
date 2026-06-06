import Foundation
import SwiftData

@MainActor
final class BudgetRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func save(_ budget: Budget) throws {
        let context = makeContext()
        context.insert(budget)
        try context.save()
    }
    
    func fetchAll() throws -> [Budget] {
        let context = makeContext()
        let descriptor = FetchDescriptor<Budget>()
        return try context.fetch(descriptor)
    }

    func fetch(forMonthYear monthYear: String) throws -> [Budget] {
        let context = makeContext()
        let targetMonthYear = monthYear
        let descriptor = FetchDescriptor<Budget>(predicate: #Predicate { $0.monthYear == targetMonthYear })
        return try context.fetch(descriptor)
    }

    func delete(_ budget: Budget) throws {
        let context = makeContext()
        let targetID = budget.id
        // Must fetch local instance first
        if let local = try context.fetch(FetchDescriptor<Budget>(predicate: #Predicate { $0.id == targetID })).first {
            context.delete(local)
            try context.save()
        }
    }
}
