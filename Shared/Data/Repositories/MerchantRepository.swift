import Foundation
import SwiftData

@MainActor
final class MerchantRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func fetchAll() throws -> [Merchant] {
        let context = makeContext()
        return try context.fetch(FetchDescriptor<Merchant>(sortBy: [SortDescriptor(\.usageCount, order: .reverse)]))
    }

    func preferredCategoryID(for canonicalName: String) throws -> UUID? {
        let context = makeContext()
        let merchants = try context.fetch(FetchDescriptor<Merchant>())
        return merchants.first(where: { $0.canonicalName.caseInsensitiveCompare(canonicalName) == .orderedSame })?.preferredCategoryID
    }

    func fetch(canonicalName: String) throws -> Merchant? {
        let context = makeContext()
        let merchants = try context.fetch(FetchDescriptor<Merchant>())
        return merchants.first(where: { $0.canonicalName.caseInsensitiveCompare(canonicalName) == .orderedSame })
    }

    func recordDecision(
        normalizedName: String,
        displayName: String,
        canonicalName: String,
        categoryID: UUID?,
        confidence: Double
    ) throws {
        guard !canonicalName.isEmpty else { return }

        let context = makeContext()
        let merchants = try context.fetch(FetchDescriptor<Merchant>())
        if let existing = merchants.first(where: { $0.canonicalName.caseInsensitiveCompare(canonicalName) == .orderedSame }) {
            existing.displayName = displayName
            existing.normalizedName = normalizedName
            existing.usageCount += 1
            existing.lastSeenAt = .now
            existing.averageConfidence = ((existing.averageConfidence * Double(max(existing.usageCount - 1, 0))) + confidence) / Double(max(existing.usageCount, 1))
            if let categoryID {
                existing.preferredCategoryID = categoryID
            }
        } else {
            let merchant = Merchant(
                normalizedName: normalizedName,
                displayName: displayName,
                canonicalName: canonicalName,
                usageCount: 1,
                preferredCategoryID: categoryID,
                averageConfidence: confidence,
                lastSeenAt: .now
            )
            context.insert(merchant)
        }

        try context.save()
    }
}
