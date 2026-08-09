import Foundation

protocol CategorizationOrchestrating {
    func categorize(_ input: NormalizedTransactionDTO) async -> CategorizationDecision
}
@MainActor
final class CategorizationOrchestrator: CategorizationOrchestrating {
    private let categoryRepository: CategoryRepository
    private let ruleEngine: RuleEngine
    private let merchantMemory: MerchantMemoryEngine
    private let classifier: StatisticalClassifier
    private let foundationResolver: FoundationModelsResolver?
    private let confidenceScorer: ConfidenceScorer
    private let directionPolicy = CategoryDirectionPolicy()

    init(
        categoryRepository: CategoryRepository,
        ruleEngine: RuleEngine,
        merchantMemory: MerchantMemoryEngine,
        classifier: StatisticalClassifier,
        foundationResolver: FoundationModelsResolver?,
        confidenceScorer: ConfidenceScorer
    ) {
        self.categoryRepository = categoryRepository
        self.ruleEngine = ruleEngine
        self.merchantMemory = merchantMemory
        self.classifier = classifier
        self.foundationResolver = foundationResolver
        self.confidenceScorer = confidenceScorer
    }

    func categorize(_ input: NormalizedTransactionDTO) async -> CategorizationDecision {
        if input.resolvedKind == .transfer,
           let category = try? categoryRepository.fetchOrCreateBaseCategory(named: "Transferencias", isIncome: false) {
            return CategorizationDecision(
                categoryID: category.id,
                subcategoryID: nil,
                source: .rule,
                confidence: 0.99,
                shouldQueueForReview: false,
                isRecurringCandidate: false,
                reason: "Detected an internal account or prepaid-card movement."
            )
        }

        if let ruleMatch = ruleEngine.match(input) {
            return finalize(ruleMatch, for: input)
        }

        if let merchantMatch = merchantMemory.match(input) {
            return finalize(merchantMatch, for: input)
        }

        if let mlMatch = classifier.predict(input) {
            let finalized = finalize(mlMatch, for: input)
            if !finalized.shouldQueueForReview || finalized.confidence >= AppConfig.softAutoCategorizationThreshold {
                return finalized
            }
        }

        if let foundationResolver {
            let aiMatch = await foundationResolver.resolve(input)
            return finalize(aiMatch, for: input)
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
            return finalize(ruleMatch, for: input)
        }

        if let mlMatch = classifier.predict(input) {
            return finalize(mlMatch, for: input)
        }

        if let merchantMatch = merchantMemory.match(input) {
            return finalize(merchantMatch, for: input)
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

    private func finalize(
        _ decision: CategorizationDecision,
        for input: NormalizedTransactionDTO
    ) -> CategorizationDecision {
        let scored = confidenceScorer.finalize(decision)
        guard let categoryID = scored.categoryID,
              let category = try? categoryRepository.fetch(categoryID: categoryID) else {
            return scored
        }
        return directionPolicy.rejectingIncompatible(
            scored,
            categoryIsIncome: category.isIncome,
            transactionKind: input.resolvedKind
        )
    }
}
