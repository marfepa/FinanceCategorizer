import Foundation

enum CategoryDirectionError: LocalizedError {
    case incompatibleCategory

    var errorDescription: String? {
        AppLanguage.currentSelection.localized("review.error.incompatibleCategory")
    }
}

/// Central invariant that prevents an income movement from being accepted as
/// an expense category (and vice versa). Transfers are handled separately by
/// the categorization pipeline and do not have an income/expense direction.
struct CategoryDirectionPolicy {
    func isCompatible(categoryIsIncome: Bool, transactionKind: TransactionKind) -> Bool {
        switch transactionKind {
        case .income:
            return categoryIsIncome
        case .expense:
            return !categoryIsIncome
        case .transfer, .adjustment:
            return true
        }
    }

    func rejectingIncompatible(
        _ decision: CategorizationDecision,
        categoryIsIncome: Bool,
        transactionKind: TransactionKind
    ) -> CategorizationDecision {
        guard isCompatible(categoryIsIncome: categoryIsIncome, transactionKind: transactionKind) else {
            return CategorizationDecision(
                categoryID: nil,
                subcategoryID: nil,
                source: decision.source,
                confidence: decision.confidence,
                shouldQueueForReview: true,
                isRecurringCandidate: decision.isRecurringCandidate,
                reason: "Suggested category is incompatible with the movement direction."
            )
        }
        return decision
    }
}
