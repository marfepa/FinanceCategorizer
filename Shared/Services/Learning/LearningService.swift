import Foundation

@MainActor
final class MerchantLearningStore {
    private let merchantRepository: MerchantRepository

    init(merchantRepository: MerchantRepository) {
        self.merchantRepository = merchantRepository
    }

    func record(normalizedName: String, displayName: String, canonicalName: String, categoryID: UUID, confidence: Double) throws {
        try merchantRepository.recordDecision(
            normalizedName: normalizedName,
            displayName: displayName,
            canonicalName: canonicalName,
            categoryID: categoryID,
            confidence: confidence
        )
    }
}

@MainActor
final class RuleSuggestionEngine {
    func shouldSuggestRule(for transaction: Transaction, categoryID: UUID) -> Bool {
        guard let merchant = transaction.merchantCanonicalName else { return false }
        return !merchant.isEmpty && transaction.confidence >= AppConfig.softAutoCategorizationThreshold && transaction.categoryID == categoryID
    }
}

@MainActor
final class CorrectionLearningService {
    private let correctionRepository: CorrectionRepository
    private let merchantLearningStore: MerchantLearningStore
    private let ruleRepository: RuleRepository
    private let transactionRepository: TransactionRepository
    private let ruleSuggestionEngine: RuleSuggestionEngine
    private let localModelManager: LocalModelManager

    init(
        correctionRepository: CorrectionRepository,
        merchantLearningStore: MerchantLearningStore,
        ruleRepository: RuleRepository,
        transactionRepository: TransactionRepository,
        ruleSuggestionEngine: RuleSuggestionEngine,
        localModelManager: LocalModelManager
    ) {
        self.correctionRepository = correctionRepository
        self.merchantLearningStore = merchantLearningStore
        self.ruleRepository = ruleRepository
        self.transactionRepository = transactionRepository
        self.ruleSuggestionEngine = ruleSuggestionEngine
        self.localModelManager = localModelManager
    }

    func applyCorrection(
        for transaction: Transaction,
        categoryID: UUID,
        subcategoryID: UUID? = nil,
        applyToFuture: Bool
    ) throws {
        let correction = UserCorrection(
            transactionID: transaction.id,
            previousCategoryID: transaction.categoryID,
            newCategoryID: categoryID,
            previousSubcategoryID: transaction.subcategoryID,
            newSubcategoryID: subcategoryID,
            previousConfidence: transaction.confidence,
            originalSourceRaw: transaction.categorizationSourceRaw
        )
        try correctionRepository.insert(correction)

        try transactionRepository.applyDecision(
            transactionID: transaction.id,
            categoryID: categoryID,
            subcategoryID: subcategoryID,
            source: .manual,
            confidence: 1.0,
            needsReview: false,
            reviewStatus: .corrected,
            reason: "Corrected manually by the user.",
            isRecurringCandidate: transaction.isRecurringCandidate
        )

        if let canonicalName = transaction.merchantCanonicalName, !canonicalName.isEmpty {
            let normalized = canonicalName.lowercased()
            try merchantLearningStore.record(
                normalizedName: normalized,
                displayName: transaction.merchantDisplayName ?? canonicalName,
                canonicalName: canonicalName,
                categoryID: categoryID,
                confidence: 1.0
            )

            if applyToFuture || ruleSuggestionEngine.shouldSuggestRule(for: transaction, categoryID: categoryID) {
                try ruleRepository.createRule(
                    name: "Rule for \(canonicalName)",
                    merchantContains: normalized,
                    descriptionContains: nil,
                    amountMin: nil,
                    amountMax: nil,
                    amountSign: transaction.amount < 0 ? -1 : 1,
                    targetCategoryID: categoryID,
                    createdFromUserCorrection: true
                )
            }
        }

        try localModelManager.rebuildModelIfNeeded()
    }
}
