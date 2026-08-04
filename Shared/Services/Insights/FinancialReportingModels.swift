import Foundation

enum FinancialTrendDirection: String, Equatable {
    case increasing
    case decreasing
    case stable
    case insufficientData
}

struct FinancialDataQuality {
    let includedTransactionCount: Int
    let expenseTransactionCount: Int
    let categorizedExpenseCount: Int
    let pendingReviewCount: Int
    let internalTransferCount: Int

    var expenseCategorizationCoverage: Double {
        guard expenseTransactionCount > 0 else { return 1 }
        return Double(categorizedExpenseCount) / Double(expenseTransactionCount)
    }

    var isReliable: Bool {
        pendingReviewCount == 0 && categorizedExpenseCount == expenseTransactionCount
    }
}

struct CategoryEvolutionPoint: Identifiable {
    let id: String
    let categoryName: String
    let monthLabel: String
    let startDate: Date
    let amount: Decimal
}

struct CategoryEvolutionItem: Identifiable {
    let id: String
    let categoryName: String
    let points: [CategoryEvolutionPoint]
    let latestAmount: Decimal
    let previousAmount: Decimal
    let deltaFromPreviousMonth: Decimal
    let deltaPercentage: Double?
    let isSpiking: Bool
}

struct FinancialMovementClassifier {
    private let kindResolver = TransactionKindResolver()

    func kind(for transaction: Transaction) -> TransactionKind {
        kindResolver.resolve(
            storedKindRaw: transaction.kindRaw,
            rawDescription: transaction.rawDescription,
            cleanedDescription: transaction.cleanedDescription,
            amount: transaction.amount
        )
    }

    func isIncluded(_ transaction: Transaction) -> Bool {
        kind(for: transaction) != .transfer
    }

    func isIncome(_ transaction: Transaction) -> Bool {
        kind(for: transaction) == .income && transaction.amount > .zero
    }

    func isExpense(_ transaction: Transaction) -> Bool {
        kind(for: transaction) == .expense && transaction.amount < .zero
    }

    func categoryName(for transaction: Transaction, categoryMap: [UUID: String]) -> String? {
        if let categoryID = transaction.categoryID, let categoryName = categoryMap[categoryID] {
            return categoryName
        }

        guard isExpense(transaction),
              CategoryTextSignals.containsSupermarket(
                  in: "\(transaction.merchantCanonicalName ?? "") \(transaction.cleanedDescription)"
              ) else {
            return nil
        }

        return categoryMap.values.first {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == "alimentacion"
        } ?? "Alimentacion"
    }

    func dataQuality(for transactions: [Transaction]) -> FinancialDataQuality {
        let included = transactions.filter(isIncluded)
        let expenses = included.filter(isExpense)
        let categorizedExpenses = expenses.filter { $0.categoryID != nil }
        let pending = included.filter {
            $0.categoryID == nil || $0.needsReview || $0.reviewStatusRaw == ReviewStatus.pending.rawValue
        }

        return FinancialDataQuality(
            includedTransactionCount: included.count,
            expenseTransactionCount: expenses.count,
            categorizedExpenseCount: categorizedExpenses.count,
            pendingReviewCount: pending.count,
            internalTransferCount: transactions.count - included.count
        )
    }

    func trend(for points: [MonthlyCashflowPoint]) -> FinancialTrendDirection {
        guard points.count >= 2 else { return .insufficientData }
        let previous = points[points.count - 2].net
        let latest = points[points.count - 1].net
        if latest > previous { return .increasing }
        if latest < previous { return .decreasing }
        return .stable
    }

    func deltaFromPreviousMonth(for points: [MonthlyCashflowPoint]) -> Decimal? {
        guard points.count >= 2 else { return nil }
        return points[points.count - 1].net - points[points.count - 2].net
    }
}
