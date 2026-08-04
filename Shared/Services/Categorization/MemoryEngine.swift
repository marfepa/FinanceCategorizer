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
    private let transactionRepository: TransactionRepository

    init(transactionRepository: TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func match(_ input: NormalizedTransactionDTO) -> CategorizationDecision? {
        let merchantText = "\(input.merchantCanonicalName ?? "") \(input.cleanedDescription)"
        guard !CategoryTextSignals.containsSupermarket(in: merchantText) else {
            // Let the deterministic supermarket signal win over stale
            // merchant memory such as a previous generic "Compras" label.
            return nil
        }

        if let merchant = input.merchantCanonicalName,
           let categoryID = preferredCategoryID(for: merchant, sign: input.sign) {
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

        guard let previous = try? transactionRepository.fetchFirst(byFingerprint: input.fingerprint, sign: input.sign),
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

    private func preferredCategoryID(for merchant: String, sign: Int) -> UUID? {
        guard let transactions = try? transactionRepository.fetchByMerchant(merchant, limit: 100) else {
            return nil
        }

        let matchingDirection = transactions.filter {
            guard $0.categoryID != nil, !$0.needsReview else { return false }
            return sign >= 0 ? $0.amount > .zero : $0.amount < .zero
        }

        return Dictionary(grouping: matchingDirection, by: { $0.categoryID! })
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?
            .key
    }
}
