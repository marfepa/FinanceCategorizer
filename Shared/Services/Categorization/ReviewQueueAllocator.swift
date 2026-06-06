import Foundation

struct ReviewQueueAllocator {
    func shouldQueue(_ decision: CategorizationDecision) -> Bool {
        decision.shouldQueueForReview
    }
}
