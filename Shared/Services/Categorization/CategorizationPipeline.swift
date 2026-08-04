import Foundation

protocol CategorizationOrchestrating {
    func categorize(_ input: NormalizedTransactionDTO) async -> CategorizationDecision
}

@MainActor
final class CategorizationOrchestrator: CategorizationOrchestrating {
    private let ruleEngine: RuleEngine
    private let merchantMemory: MerchantMemoryEngine
    private let classifier: StatisticalClassifier
    private let foundationResolver: FoundationModelsResolver?
    private let confidenceScorer: ConfidenceScorer

    init(
        ruleEngine: RuleEngine,
        merchantMemory: MerchantMemoryEngine,
        classifier: StatisticalClassifier,
        foundationResolver: FoundationModelsResolver?,
        confidenceScorer: ConfidenceScorer
    ) {
        self.ruleEngine = ruleEngine
        self.merchantMemory = merchantMemory
        self.classifier = classifier
        self.foundationResolver = foundationResolver
        self.confidenceScorer = confidenceScorer
    }

    func categorize(_ input: NormalizedTransactionDTO) async -> CategorizationDecision {
        if let ruleMatch = ruleEngine.match(input) {
            return confidenceScorer.finalize(ruleMatch)
        }

        if let merchantMatch = merchantMemory.match(input) {
            return confidenceScorer.finalize(merchantMatch)
        }

        if let mlMatch = classifier.predict(input) {
            let finalized = confidenceScorer.finalize(mlMatch)
            if !finalized.shouldQueueForReview || finalized.confidence >= AppConfig.softAutoCategorizationThreshold {
                return finalized
            }
        }

        if let foundationResolver {
            let aiMatch = await foundationResolver.resolve(input)
            return confidenceScorer.finalize(aiMatch)
        }

        return CategorizationDecision(
            categoryID: nil,
            subcategoryID: nil,
            source: .unknown,
            confidence: 0,
            shouldQueueForReview: true,
            isRecurringCandidate: false,
            reason: "No reliable match."
        )
    }

    /// Runs the deterministic ranking used to audit an existing category.
    /// It deliberately avoids merchant memory and Foundation Models first:
    /// both can repeat a previous decision instead of detecting that it is
    /// inconsistent with the current transaction text.
    func recommendRecategorization(_ input: NormalizedTransactionDTO) async -> CategorizationDecision {
        if let ruleMatch = ruleEngine.match(input) {
            return confidenceScorer.finalize(ruleMatch)
        }

        if let mlMatch = classifier.predict(input) {
            return confidenceScorer.finalize(mlMatch)
        }

        if let merchantMatch = merchantMemory.match(input) {
            return confidenceScorer.finalize(merchantMatch)
        }

        return CategorizationDecision(
            categoryID: nil,
            subcategoryID: nil,
            source: .unknown,
            confidence: 0,
            shouldQueueForReview: true,
            isRecurringCandidate: false,
            reason: "No reliable recategorization signal."
        )
    }
}
