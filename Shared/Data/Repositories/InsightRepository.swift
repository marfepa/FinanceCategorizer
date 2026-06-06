import Foundation
import SwiftData

@MainActor
final class InsightRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func replaceAll(with insights: [Insight]) throws {
        let context = makeContext()
        let existing = try context.fetch(FetchDescriptor<Insight>())
        for item in existing {
            context.delete(item)
        }
        for insight in insights {
            context.insert(insight)
        }
        try context.save()
    }

    func fetchAll() throws -> [Insight] {
        let context = makeContext()
        return try context.fetch(FetchDescriptor<Insight>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }
}
