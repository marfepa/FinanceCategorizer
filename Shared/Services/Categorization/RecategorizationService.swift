import Foundation

struct RecategorizationRunResult {
    let evaluatedCount: Int
    let suggestionsCreated: Int
    let autoResolved: Int
    let unchangedCount: Int
}

@MainActor
final class RecategorizationService {
    private let transactionRepository: TransactionRepository
    private let categorizationOrchestrator: CategorizationOrchestrator

    init(
        transactionRepository: TransactionRepository,
        categorizationOrchestrator: CategorizationOrchestrator
    ) {
        self.transactionRepository = transactionRepository
        self.categorizationOrchestrator = categorizationOrchestrator
    }

    func analyzeAll() async throws -> RecategorizationRunResult {
        try await analyze(try transactionRepository.fetchRecategorizationCandidates())
    }

    func analyze(_ transactions: [Transaction]) async throws -> RecategorizationRunResult {
        var suggestionsCreated = 0
        var autoResolved = 0
        var unchangedCount = 0

        for transaction in transactions where isEligible(transaction) {
            let decision = await categorizationOrchestrator.recommendRecategorization(
                normalizedDTO(from: transaction)
            )

            guard let categoryID = decision.categoryID,
                  decision.confidence >= AppConfig.suggestionThreshold else {
                unchangedCount += 1
                continue
            }

            if transaction.categoryID == nil {
                let shouldAutoResolve = !decision.shouldQueueForReview &&
                    decision.confidence >= AppConfig.softAutoCategorizationThreshold

                if shouldAutoResolve {
                    try transactionRepository.applyDecision(
                        transactionID: transaction.id,
                        categoryID: categoryID,
                        subcategoryID: decision.subcategoryID,
                        source: decision.source,
                        confidence: decision.confidence,
                        needsReview: false,
                        reviewStatus: .accepted,
                        reason: "[Automatic categorization] \(decision.reason)",
                        isRecurringCandidate: decision.isRecurringCandidate
                    )
                    autoResolved += 1
                } else {
                    try transactionRepository.saveRecategorizationSuggestion(
                        transactionID: transaction.id,
                        categoryID: categoryID,
                        subcategoryID: decision.subcategoryID,
                        source: decision.source,
                        confidence: decision.confidence,
                        reason: decision.reason
                    )
                    suggestionsCreated += 1
                }
                continue
            }

            guard transaction.categoryID != categoryID else {
                if transaction.hasRecategorizationSuggestion {
                    try transactionRepository.clearRecategorizationSuggestion(transactionID: transaction.id)
                }
                unchangedCount += 1
                continue
            }

            // Existing categories are never overwritten by an audit. The
            // proposal remains actionable in the review queue instead.
            try transactionRepository.saveRecategorizationSuggestion(
                transactionID: transaction.id,
                categoryID: categoryID,
                subcategoryID: decision.subcategoryID,
                source: decision.source,
                confidence: decision.confidence,
                reason: decision.reason
            )
            suggestionsCreated += 1
        }

        return RecategorizationRunResult(
            evaluatedCount: transactions.count(where: { self.isEligible($0) }),
            suggestionsCreated: suggestionsCreated,
            autoResolved: autoResolved,
            unchangedCount: unchangedCount
        )
    }

    private func isEligible(_ transaction: Transaction) -> Bool {
        transaction.resolvedKind != .transfer &&
            transaction.categorizationSourceRaw != CategorizationSource.manual.rawValue
    }

    private func normalizedDTO(from transaction: Transaction) -> NormalizedTransactionDTO {
        NormalizedTransactionDTO(
            externalID: transaction.externalID,
            bookingDate: transaction.bookingDate,
            valueDate: transaction.valueDate,
            rawDescription: transaction.rawDescription,
            cleanedDescription: transaction.cleanedDescription,
            merchantDisplayName: transaction.merchantDisplayName,
            merchantCanonicalName: transaction.merchantCanonicalName,
            amount: transaction.amount,
            currencyCode: transaction.currencyCode,
            accountName: transaction.accountName,
            sign: transaction.amount >= 0 ? 1 : -1,
            fingerprint: transaction.fingerprint
        )
    }
}
