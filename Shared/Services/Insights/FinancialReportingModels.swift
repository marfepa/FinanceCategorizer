import Foundation

enum FinancialReportingDateBasis {
    case booking
    /// Family-budget view: ordinary payroll booked after the cutoff is assigned
    /// to the following month, while an estimated extraordinary excess stays
    /// in the month in which the bank booked it.
    case budget
    /// Kept as a source-compatible name for callers from the first reporting
    /// implementation. It now means the same as `.budget`.
    case accounting

    var usesBudgetAllocation: Bool {
        switch self {
        case .booking: return false
        case .budget, .accounting: return true
        }
    }
}

typealias DashboardDateBasis = FinancialReportingDateBasis

/// A reporting line may represent all or only part of a source transaction.
/// This is required for a payroll month that contains both ordinary payroll
/// and an estimated extraordinary supplement.
struct FinancialReportingEntry {
    let transaction: Transaction
    let date: Date
    let amount: Decimal
}

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

    func isIncluded(_ transaction: Transaction, categoryMap: [UUID: String] = [:]) -> Bool {
        !isInternalTransfer(transaction, categoryMap: categoryMap)
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

    func isInternalTransfer(_ transaction: Transaction, categoryMap: [UUID: String] = [:]) -> Bool {
        if kind(for: transaction) == .transfer {
            return true
        }

        guard let categoryID = transaction.categoryID,
              let categoryName = categoryMap[categoryID] else {
            return false
        }

        let normalizedCategory = categoryName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalizedCategory == "MOVIMIENTO INTERNO" ||
            normalizedCategory == "INTERNAL MOVEMENT"
    }

    func dataQuality(for transactions: [Transaction], categoryMap: [UUID: String] = [:]) -> FinancialDataQuality {
        let included = transactions.filter { isIncluded($0, categoryMap: categoryMap) }
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
/// Dashboard and Analysis must agree on the reporting month they are showing.
/// Keeping this decision here prevents a future-dated movement from silently
/// moving one screen to a different month than the other.
struct FinancialReportingScope {
    let now: Date
    let dateBasis: DashboardDateBasis
    let calendar: Calendar
    let payrollCutoffDay: Int

    init(
        now: Date = .now,
        dateBasis: DashboardDateBasis = .budget,
        calendar: Calendar = .current,
        payrollCutoffDay: Int? = nil
    ) {
        self.now = now
        self.dateBasis = dateBasis
        self.calendar = calendar
        let storedCutoff = UserDefaults.standard.integer(forKey: "payrollCutoffDay")
        let requestedCutoff = payrollCutoffDay ?? (storedCutoff == 0 ? 25 : storedCutoff)
        self.payrollCutoffDay = min(max(requestedCutoff, 22), 31)
    }

    func date(for transaction: Transaction) -> Date {
        // A source transaction has one bank date. Budget allocations are
        // represented by FinancialReportingEntry rather than by mutating this
        // source-level date.
        return transaction.bookingDate
    }

    func isVisible(_ transaction: Transaction) -> Bool {
        calendar.startOfDay(for: transaction.bookingDate) <= calendar.startOfDay(for: now)
    }

    func eligibleTransactions(
        from transactions: [Transaction],
        classifier: FinancialMovementClassifier,
        categoryMap: [UUID: String] = [:]
    ) -> [Transaction] {
        transactions
            .filter { classifier.isIncluded($0, categoryMap: categoryMap) }
            .filter(isVisible)
    }

    func eligibleEntries(
        from transactions: [Transaction],
        classifier: FinancialMovementClassifier,
        categoryMap: [UUID: String] = [:]
    ) -> [FinancialReportingEntry] {
        let eligible = eligibleTransactions(
            from: transactions,
            classifier: classifier,
            categoryMap: categoryMap
        )

        guard dateBasis.usesBudgetAllocation else {
            return eligible.map {
                FinancialReportingEntry(transaction: $0, date: $0.bookingDate, amount: $0.amount)
            }
        }

        return budgetEntries(from: eligible, classifier: classifier)
    }

    func sourceTransactions(from entries: [FinancialReportingEntry]) -> [Transaction] {
        var seen = Set<UUID>()
        return entries.compactMap { entry in
            guard seen.insert(entry.transaction.id).inserted else { return nil }
            return entry.transaction
        }
    }

    func activeMonthStart(
        from transactions: [Transaction],
        classifier: FinancialMovementClassifier,
        categoryMap: [UUID: String] = [:]
    ) -> Date? {
        let eligible = eligibleTransactions(
            from: transactions,
            classifier: classifier,
            categoryMap: categoryMap
        )
        let latestKnownDate: Date?
        if dateBasis.usesBudgetAllocation {
            let reportingEntries = eligibleEntries(
                from: eligible,
                classifier: classifier,
                categoryMap: categoryMap
            )
            latestKnownDate = reportingEntries
                .filter { calendar.startOfDay(for: $0.date) <= calendar.startOfDay(for: now) }
                .map(\.date)
                .max()
        } else {
            latestKnownDate = eligible.map({ date(for: $0) }).max()
        }
        guard let latestKnownDate else { return nil }

        let calendarMonthStart = startOfMonth(for: now)
        let nextCalendarMonth = calendar.date(byAdding: .month, value: 1, to: calendarMonthStart)
        let currentMonthHasEntries: Bool
        if dateBasis.usesBudgetAllocation {
            currentMonthHasEntries = eligibleEntries(
                from: eligible,
                classifier: classifier,
                categoryMap: categoryMap
            ).contains { entry in
                let date = entry.date
                return date >= calendarMonthStart &&
                    date < (nextCalendarMonth ?? .distantFuture) &&
                    calendar.startOfDay(for: date) <= calendar.startOfDay(for: now)
            }
        } else {
            currentMonthHasEntries = eligible.contains { transaction in
                let date = date(for: transaction)
                return date >= calendarMonthStart && date < (nextCalendarMonth ?? .distantFuture)
            }
        }
        if currentMonthHasEntries {
            return calendarMonthStart
        }

        return startOfMonth(for: latestKnownDate)
    }

    private func budgetEntries(
        from transactions: [Transaction],
        classifier: FinancialMovementClassifier
    ) -> [FinancialReportingEntry] {
        let latePayroll = transactions.filter { transaction in
            guard isPayroll(transaction, classifier: classifier) else { return false }
            return calendar.component(.day, from: transaction.bookingDate) >= payrollCutoffDay
        }

        let groupedPayroll = Dictionary(grouping: latePayroll) {
            startOfMonth(for: $0.bookingDate)
        }
        let payrollTotals = groupedPayroll.values.map { items in
            items.reduce(Decimal.zero) { $0 + $1.amount }
        }
        let typicalPayroll = median(payrollTotals)
        let canDetectExtraordinaryIncome = payrollTotals.count >= 3 && typicalPayroll > .zero

        var entries = transactions
            .filter { transaction in
                !latePayroll.contains { payrollTransaction in
                    payrollTransaction.id == transaction.id
                }
            }
            .map { FinancialReportingEntry(transaction: $0, date: $0.bookingDate, amount: $0.amount) }

        for (month, items) in groupedPayroll {
            let total = items.reduce(Decimal.zero) { $0 + $1.amount }
            let isExtraordinary = canDetectExtraordinaryIncome && total > typicalPayroll * Decimal(string: "1.5")!
            let ordinaryAmount = isExtraordinary ? min(total, typicalPayroll) : total
            let ordinaryDate = calendar.date(byAdding: .month, value: 1, to: month) ?? month

            var ordinaryRemaining = ordinaryAmount
            let sortedItems = items.sorted {
                if $0.bookingDate != $1.bookingDate { return $0.bookingDate < $1.bookingDate }
                return $0.id.uuidString < $1.id.uuidString
            }

            for (index, transaction) in sortedItems.enumerated() {
                let ordinaryShare: Decimal
                if index == sortedItems.count - 1 {
                    ordinaryShare = ordinaryRemaining
                } else if total == .zero {
                    ordinaryShare = .zero
                } else {
                    let proportional = roundedToCents(transaction.amount * ordinaryAmount / total)
                    ordinaryShare = min(max(proportional, .zero), ordinaryRemaining)
                }
                ordinaryRemaining -= ordinaryShare

                if ordinaryShare > .zero {
                    entries.append(
                        FinancialReportingEntry(
                            transaction: transaction,
                            date: ordinaryDate,
                            amount: ordinaryShare
                        )
                    )
                }

                let extraordinaryShare = transaction.amount - ordinaryShare
                if extraordinaryShare > .zero {
                    entries.append(
                        FinancialReportingEntry(
                            transaction: transaction,
                            date: transaction.bookingDate,
                            amount: extraordinaryShare
                        )
                    )
                }
            }
        }

        return entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.transaction.bookingDate < rhs.transaction.bookingDate
        }
    }

    private func isPayroll(_ transaction: Transaction, classifier: FinancialMovementClassifier) -> Bool {
        guard classifier.isIncome(transaction) else { return false }
        let text = "\(transaction.rawDescription) \(transaction.cleanedDescription)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
        return text.contains("NOMINA")
    }

    private func median(_ values: [Decimal]) -> Decimal {
        let sorted = values.filter { $0 > .zero }.sorted()
        guard !sorted.isEmpty else { return .zero }
        if sorted.count % 2 == 1 {
            return sorted[sorted.count / 2]
        }
        let upper = sorted.count / 2
        return (sorted[upper - 1] + sorted[upper]) / Decimal(2)
    }

    private func roundedToCents(_ value: Decimal) -> Decimal {
        var value = value
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &value, 2, .bankers)
        return rounded
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
