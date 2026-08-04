import Foundation

struct CategorizationDecision {
    let categoryID: UUID?
    let subcategoryID: UUID?
    let source: CategorizationSource
    let confidence: Double
    let shouldQueueForReview: Bool
    let isRecurringCandidate: Bool
    let reason: String
}

struct ConfidenceScorer {
    func finalize(_ decision: CategorizationDecision) -> CategorizationDecision {
        let score = ConfidenceScore(value: decision.confidence)
        if score.shouldAutoAccept {
            return CategorizationDecision(
                categoryID: decision.categoryID,
                subcategoryID: decision.subcategoryID,
                source: decision.source,
                confidence: decision.confidence,
                shouldQueueForReview: false,
                isRecurringCandidate: decision.isRecurringCandidate,
                reason: decision.reason
            )
        }

        return CategorizationDecision(
            categoryID: decision.categoryID,
            subcategoryID: decision.subcategoryID,
            source: decision.source,
            confidence: decision.confidence,
            shouldQueueForReview: decision.shouldQueueForReview || score.shouldSendToReview || decision.categoryID == nil,
            isRecurringCandidate: decision.isRecurringCandidate,
            reason: decision.reason
        )
    }
}
