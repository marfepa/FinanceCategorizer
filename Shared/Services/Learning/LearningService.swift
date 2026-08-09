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
    private let categoryRepository: CategoryRepository
    private let merchantLearningStore: MerchantLearningStore
    private let ruleRepository: RuleRepository
    private let transactionRepository: TransactionRepository
    private let ruleSuggestionEngine: RuleSuggestionEngine
    private let localModelManager: LocalModelManager

    init(
        correctionRepository: CorrectionRepository,
        categoryRepository: CategoryRepository,
        merchantLearningStore: MerchantLearningStore,
        ruleRepository: RuleRepository,
        transactionRepository: TransactionRepository,
        ruleSuggestionEngine: RuleSuggestionEngine,
        localModelManager: LocalModelManager
    ) {
        self.correctionRepository = correctionRepository
        self.categoryRepository = categoryRepository
        self.merchantLearningStore = merchantLearningStore
        self.ruleRepository = ruleRepository
        self.transactionRepository = transactionRepository
        self.ruleSuggestionEngine = ruleSuggestionEngine
        self.localModelManager = localModelManager
    }

    @discardableResult
    func applyCorrection(
        for transaction: Transaction,
        categoryID: UUID,
        subcategoryID: UUID? = nil,
        applyToFuture: Bool = true
    ) throws -> Int {
        guard let category = try categoryRepository.fetch(categoryID: categoryID),
              CategoryDirectionPolicy().isCompatible(
                categoryIsIncome: category.isIncome,
                transactionKind: transaction.resolvedKind
              ) else {
            throw CategoryDirectionError.incompatibleCategory
        }

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

        let matchingTransactions = (try? transactionRepository.fetchMatchingNameTransactions(for: transaction)) ?? []
        var cascadedCount = 1

        for match in matchingTransactions {
            let matchCorrection = UserCorrection(
                transactionID: match.id,
                previousCategoryID: match.categoryID,
                newCategoryID: categoryID,
                previousSubcategoryID: match.subcategoryID,
                newSubcategoryID: subcategoryID,
                previousConfidence: match.confidence,
                originalSourceRaw: match.categorizationSourceRaw
            )
            try correctionRepository.insert(matchCorrection)

            try transactionRepository.applyDecision(
                transactionID: match.id,
                categoryID: categoryID,
                subcategoryID: subcategoryID,
                source: .manual,
                confidence: 1.0,
                needsReview: false,
                reviewStatus: .corrected,
                reason: "Automatically updated from user recategorization of matching transaction.",
                isRecurringCandidate: match.isRecurringCandidate
            )
            cascadedCount += 1
        }

        let merchantName = transaction.merchantCanonicalName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDesc = transaction.cleanedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDesc = transaction.rawDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        if let merchantName, !merchantName.isEmpty, !merchantName.isGenericBankingNoise {
            let normalized = merchantName.lowercased()
            try merchantLearningStore.record(
                normalizedName: normalized,
                displayName: transaction.merchantDisplayName ?? merchantName,
                canonicalName: merchantName,
                categoryID: categoryID,
                confidence: 1.0
            )

            if applyToFuture || ruleSuggestionEngine.shouldSuggestRule(for: transaction, categoryID: categoryID) {
                try ruleRepository.createRule(
                    name: "Rule for \(merchantName)",
                    merchantContains: normalized,
                    descriptionContains: nil,
                    amountMin: nil,
                    amountMax: nil,
                    amountSign: transaction.amount < 0 ? -1 : 1,
                    targetCategoryID: categoryID,
                    createdFromUserCorrection: true
                )
            }
        } else if !cleanedDesc.isEmpty || !rawDesc.isEmpty {
            let targetText = !cleanedDesc.isEmpty ? cleanedDesc : rawDesc
            let normalized = targetText.lowercased()

            if !normalized.isGenericBankingNoise {
                if applyToFuture || ruleSuggestionEngine.shouldSuggestRule(for: transaction, categoryID: categoryID) {
                    try ruleRepository.createRule(
                        name: "Rule for \(targetText)",
                        merchantContains: nil,
                        descriptionContains: normalized,
                        amountMin: nil,
                        amountMax: nil,
                        amountSign: transaction.amount < 0 ? -1 : 1,
                        targetCategoryID: categoryID,
                        createdFromUserCorrection: true
                    )
                }
            }
        }

        try localModelManager.rebuildModelIfNeeded()
        return cascadedCount
    }
}
