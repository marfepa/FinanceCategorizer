import Foundation
import SwiftData

@MainActor
final class CorrectionRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func insert(_ correction: UserCorrection) throws {
        let context = makeContext()
        context.insert(correction)
        try context.save()
    }

    func fetchAll() throws -> [UserCorrection] {
        let context = makeContext()
        return try context.fetch(FetchDescriptor<UserCorrection>(sortBy: [SortDescriptor(\.correctedAt, order: .reverse)]))
    }

    func countForMerchantCategory(categoryID: UUID, merchantCanonicalName: String, transactionRepository: TransactionRepository) throws -> Int {
        let corrections = try fetchAll()
        let transactionIDs = try transactionRepository.fetchByMerchant(merchantCanonicalName, limit: 500).map(\.id)
        let transactionIDSet = Set(transactionIDs)
        return corrections.filter { $0.newCategoryID == categoryID && transactionIDSet.contains($0.transactionID) }.count
    }
}
