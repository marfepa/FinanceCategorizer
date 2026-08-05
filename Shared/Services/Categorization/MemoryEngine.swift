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

        if let previous = try? transactionRepository.fetchFirst(byFingerprint: input.fingerprint, sign: input.sign),
           let categoryID = previous.categoryID {
            return CategorizationDecision(
                categoryID: categoryID,
                subcategoryID: previous.subcategoryID,
                source: .merchantMemory,
                confidence: 0.93,
                shouldQueueForReview: false,
                isRecurringCandidate: previous.isRecurringCandidate,
                reason: "Matched a previous normalized transaction fingerprint."
            )
        }

        if let merchant = input.merchantCanonicalName,
           let memoryMatch = preferredCategoryMatch(for: merchant, sign: input.sign) {
            return CategorizationDecision(
                categoryID: memoryMatch.categoryID,
                subcategoryID: nil,
                source: .merchantMemory,
                confidence: memoryMatch.confidence,
                shouldQueueForReview: false,
                isRecurringCandidate: false,
                reason: "Learned from \(memoryMatch.count) confirmed transactions for merchant '\(merchant)'."
            )
        }
        return nil
    }

    private func preferredCategoryMatch(for merchant: String, sign: Int) -> (categoryID: UUID, count: Int, confidence: Double)? {
        guard let transactions = try? transactionRepository.fetchByMerchant(merchant, limit: 100) else {
            return nil
        }

        let matchingDirection = transactions.filter {
            guard $0.categoryID != nil, !$0.needsReview else { return false }
            return sign >= 0 ? $0.amount > .zero : $0.amount < .zero
        }

        let ranked = Dictionary(grouping: matchingDirection, by: { $0.categoryID! })
            .map { categoryID, items in
                let averageConfidence = items.map(\.confidence).reduce(0, +) / Double(items.count)
                return (categoryID: categoryID, count: items.count, averageConfidence: averageConfidence)
            }
            .sorted {
                if $0.count == $1.count {
                    return $0.averageConfidence > $1.averageConfidence
                }
                return $0.count > $1.count
            }

        guard let winner = ranked.first else { return nil }
        if let runnerUp = ranked.dropFirst().first, winner.count == runnerUp.count {
            return nil
        }

        let voteConfidence = min(0.96, 0.78 + Double(min(winner.count, 4)) * 0.04)
        let confidence = max(voteConfidence, min(0.96, winner.averageConfidence))
        return (winner.categoryID, winner.count, confidence)
    }
}
