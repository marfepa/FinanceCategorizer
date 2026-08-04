import Foundation

enum FinancialReportingDateBasis {
    case booking
    case accounting
}

typealias DashboardDateBasis = FinancialReportingDateBasis

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

/// Shared temporal scope for every financial surface.
///
/// Dashboard and Analysis must agree on the accounting month they are showing.
/// Keeping this decision here prevents a future-dated movement from silently
/// moving one screen to a different month than the other.
struct FinancialReportingScope {
    let now: Date
    let dateBasis: DashboardDateBasis
    let calendar: Calendar

    init(
        now: Date = .now,
        dateBasis: DashboardDateBasis = .accounting,
        calendar: Calendar = .current
    ) {
        self.now = now
        self.dateBasis = dateBasis
        self.calendar = calendar
    }

    func date(for transaction: Transaction) -> Date {
        switch dateBasis {
        case .booking:
            return transaction.bookingDate
        case .accounting:
            return transaction.accountingDate
        }
    }

    func isVisible(_ transaction: Transaction) -> Bool {
        calendar.startOfDay(for: date(for: transaction)) <= calendar.startOfDay(for: now)
    }

    func eligibleTransactions(
        from transactions: [Transaction],
        classifier: FinancialMovementClassifier
    ) -> [Transaction] {
        transactions
            .filter(classifier.isIncluded)
            .filter(isVisible)
    }

    func activeMonthStart(
        from transactions: [Transaction],
        classifier: FinancialMovementClassifier
    ) -> Date? {
        let eligible = eligibleTransactions(from: transactions, classifier: classifier)
        guard let latestKnownDate = eligible.map({ date(for: $0) }).max() else { return nil }

        let calendarMonthStart = startOfMonth(for: now)
        let nextCalendarMonth = calendar.date(byAdding: .month, value: 1, to: calendarMonthStart)
        if eligible.contains(where: { transaction in
            let date = date(for: transaction)
            return date >= calendarMonthStart && date < (nextCalendarMonth ?? .distantFuture)
        }) {
            return calendarMonthStart
        }

        return startOfMonth(for: latestKnownDate)
    }

    func transactions(
        from transactions: [Transaction],
        in range: AnalysisTimeRange,
        anchoredAt anchorMonthStart: Date?
    ) -> [Transaction] {
        let visibleTransactions = transactions.filter(isVisible)
        guard let monthWindow = range.monthWindow,
              let anchorMonthStart,
              let startDate = calendar.date(
                  byAdding: .month,
                  value: -(monthWindow - 1),
                  to: anchorMonthStart
              ),
              let endDate = calendar.date(byAdding: .month, value: 1, to: anchorMonthStart) else {
            return visibleTransactions.sorted { date(for: $0) < date(for: $1) }
        }

        return visibleTransactions
            .filter { transaction in
                let date = date(for: transaction)
                return date >= startDate && date < endDate
            }
            .sorted { date(for: $0) < date(for: $1) }
    }

    func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
