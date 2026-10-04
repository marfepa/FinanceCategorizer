import Foundation

@MainActor
final class RuleSuggestionEngine {
    func shouldSuggestRule(for transaction: Transaction, categoryID: UUID) -> Bool {
        guard let merchant = transaction.merchantCanonicalName else { return false }
        return !merchant.isEmpty && transaction.confidence >= AppConfig.softAutoCategorizationThreshold && transaction.categoryID == categoryID
    }
}

@MainActor
final class CorrectionLearningService {
    let batchService: CorrectionBatchService

    init(batchService: CorrectionBatchService) {
        self.batchService = batchService
    }

    /// Corrects a movement and propagates the category to other non-manual
    /// movements with the same counterparty, in a single save. Used by screens
    /// outside the review queue, which keep their historical behaviour.
    @discardableResult
    func applyCorrection(
        for transaction: Transaction,
        categoryID: UUID,
        subcategoryID: UUID? = nil,
        applyToFuture: Bool = true
    ) throws -> Int {
        let batch = try batchService.applyCategories(
            [CorrectionRequest(transactionID: transaction.id, categoryID: categoryID, subcategoryID: subcategoryID)],
            action: .reassign,
            propagateToMatches: true,
            rulePolicy: .explicitOrSuggested,
            createRules: applyToFuture,
            recordHistory: false
        )
        return batch.totalCount
    }
}
