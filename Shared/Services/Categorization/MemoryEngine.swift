import Foundation

struct MerchantCategoryStats {
    let merchant: String
    let categoryID: UUID
    let count: Int
    let averageConfidence: Double
    let lastUsedAt: Date
}

@MainActor
final class MerchantMemoryEngine {
    private let merchantRepository: MerchantRepository
    private let transactionRepository: TransactionRepository

    init(merchantRepository: MerchantRepository, transactionRepository: TransactionRepository) {
        self.merchantRepository = merchantRepository
        self.transactionRepository = transactionRepository
    }

    func match(_ input: NormalizedTransactionDTO) -> CategorizationDecision? {
        if let merchant = input.merchantCanonicalName,
           let categoryID = try? merchantRepository.preferredCategoryID(for: merchant) {
            return CategorizationDecision(
                categoryID: categoryID,
                subcategoryID: nil,
                source: .merchantMemory,
                confidence: 0.95,
                shouldQueueForReview: false,
                isRecurringCandidate: false,
                reason: "Learned from previous confirmed transactions for merchant '\(merchant)'."
            )
        }

        guard let previous = try? transactionRepository.fetchFirst(byFingerprint: input.fingerprint),
              let categoryID = previous.categoryID else {
            return nil
        }

        return CategorizationDecision(
            categoryID: categoryID,
            subcategoryID: previous.subcategoryID,
            source: .merchantMemory,
            confidence: 0.88,
            shouldQueueForReview: false,
            isRecurringCandidate: previous.isRecurringCandidate,
            reason: "Matched a previous normalized transaction fingerprint."
        )
    }
}
