import Foundation
import SwiftData

@MainActor
final class SavingsGoalRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func fetchAll() throws -> [SavingsGoal] {
        try makeContext().fetch(FetchDescriptor<SavingsGoal>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    func save(_ goal: SavingsGoal) throws {
        guard goal.targetAmount > .zero else { return }
        let context = makeContext()
        let goalID = goal.id
        if let existing = try context.fetch(FetchDescriptor<SavingsGoal>(predicate: #Predicate { $0.id == goalID })).first {
            existing.name = goal.name
            existing.kindRaw = goal.kindRaw
            existing.targetAmount = goal.targetAmount
            existing.allocatedAmount = goal.allocatedAmount
            existing.monthlyContribution = goal.monthlyContribution
            existing.targetDate = goal.targetDate
            existing.isActive = goal.isActive
        } else {
            context.insert(goal)
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        let context = makeContext()
        guard let goal = try context.fetch(FetchDescriptor<SavingsGoal>(predicate: #Predicate { $0.id == id })).first else { return }
        context.delete(goal)
        try context.save()
    }
}
