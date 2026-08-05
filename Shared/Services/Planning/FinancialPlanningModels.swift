import Foundation

enum BalanceSource: String {
    case manual
    case statement
    case estimated
}

struct AccountPosition: Identifiable {
    let id: UUID
    let name: String
    let balance: Decimal
    let signedBalance: Decimal
    let isLiability: Bool
    let source: BalanceSource
    let asOf: Date?

    var isConfirmed: Bool {
        source != .estimated
    }
}

struct BalanceProjectionPoint: Identifiable {
    let id: Date
    let date: Date
    let balance: Decimal
    let availableBalance: Decimal
    let isProjected: Bool
}

struct SavingsGoalProjection: Identifiable {
    let id: UUID
    let name: String
    let kind: SavingsGoalKind
    let allocatedAmount: Decimal
    let targetAmount: Decimal
    let monthlyContribution: Decimal
    let projectedAmount: Decimal
    let targetDate: Date?
    let monthsToTarget: Int

    var progress: Double {
        guard targetAmount > .zero else { return 1 }
        return min(max(NSDecimalNumber(decimal: projectedAmount / targetAmount).doubleValue, 0), 1)
    }

    var isOnTrack: Bool {
        projectedAmount >= targetAmount
    }
}

struct FinancialPlanningSnapshot {
    let positions: [AccountPosition]
    let goals: [SavingsGoalProjection]
    let totalBalance: Decimal
    let allocatedToGoals: Decimal
    let availableBalance: Decimal
    let monthlySavingsAverage: Decimal
    let historicalMonthlySavingsAverage: Decimal
    let recurringMonthlyIncome: Decimal
    let recurringMonthlyExpenses: Decimal
    let historyMonths: Int
    let projectedBalance12Months: Decimal
    let projectedAvailableBalance12Months: Decimal
    let balanceProjection: [BalanceProjectionPoint]

    var isBalanceConfirmed: Bool {
        !positions.isEmpty && positions.allSatisfy(\.isConfirmed)
    }

    var plannedMonthlyGoalContributions: Decimal {
        goals.reduce(Decimal.zero) { $0 + $1.monthlyContribution }
    }
}

struct FinancialPlanningService {
    private let classifier = FinancialMovementClassifier()

    private struct RecurringCashflowEstimate {
        let recurringIncome: Decimal
        let recurringExpenses: Decimal
        let historicalIncomeAverage: Decimal
        let historicalExpenseAverage: Decimal
        let historyMonths: Int
    }

    private struct RecurringCashflowGroup {
        let monthlyAmounts: [Date: Decimal]
        let typicalMonthlyAmount: Decimal
        let categoryKey: String?
        let isTemporary: Bool
    }

    func buildSnapshot(
        transactions: [Transaction],
        accounts: [Account],
        goals: [SavingsGoal],
        categories: [Category] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> FinancialPlanningSnapshot {
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let includedTransactions = transactions
            .filter { classifier.isIncluded($0, categoryMap: categoryMap) }
            .filter { calendar.startOfDay(for: $0.bookingDate) <= calendar.startOfDay(for: now) }

        let accountByKey = accounts.reduce(into: [String: Account]()) { result, account in
            result[accountKey(account.name)] = account
        }
        let transactionsByAccount = Dictionary(grouping: includedTransactions, by: { accountKey($0.accountName) })
        var accountKeys = Set(accountByKey.keys)
        accountKeys.formUnion(transactionsByAccount.keys)

        if accountKeys.isEmpty {
            accountKeys.insert(Self.defaultAccountName)
        }

        let positions = accountKeys
            .sorted()
            .map { key in
                position(
                    key: key,
                    account: accountByKey[key],
                    transactions: transactionsByAccount[key] ?? [],
                    now: now
                )
            }

        let totalBalance = positions.reduce(Decimal.zero) { $0 + $1.signedBalance }
        let activeGoals = goals.filter(\.isActive)
        let allocatedToGoals = activeGoals.reduce(Decimal.zero) { $0 + $1.allocatedAmount }
        let availableBalance = totalBalance - allocatedToGoals
        let cashflowEstimate = recurringCashflowEstimate(
            transactions: transactions,
            categories: categories,
            now: now,
            calendar: calendar
        )
        let monthlySavingsAverage = cashflowEstimate.recurringIncome - cashflowEstimate.recurringExpenses
        let goalProjections = activeGoals.map {
            project($0, now: now, calendar: calendar)
        }
        let plannedContributions = goalProjections.reduce(Decimal.zero) { $0 + $1.monthlyContribution }
        let projectedBalance12Months = totalBalance + monthlySavingsAverage * Decimal(12)
        let projectedAvailableBalance12Months = availableBalance + (monthlySavingsAverage - plannedContributions) * Decimal(12)
        let balanceProjection = makeBalanceProjection(
            totalBalance: totalBalance,
            availableBalance: availableBalance,
            monthlySavingsAverage: monthlySavingsAverage,
            plannedMonthlyGoalContributions: plannedContributions,
            now: now,
            calendar: calendar
        )

        return FinancialPlanningSnapshot(
            positions: positions,
            goals: goalProjections.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
            totalBalance: totalBalance,
            allocatedToGoals: allocatedToGoals,
            availableBalance: availableBalance,
            monthlySavingsAverage: monthlySavingsAverage,
            historicalMonthlySavingsAverage: cashflowEstimate.historicalIncomeAverage - cashflowEstimate.historicalExpenseAverage,
            recurringMonthlyIncome: cashflowEstimate.recurringIncome,
            recurringMonthlyExpenses: cashflowEstimate.recurringExpenses,
            historyMonths: cashflowEstimate.historyMonths,
            projectedBalance12Months: projectedBalance12Months,
            projectedAvailableBalance12Months: projectedAvailableBalance12Months,
            balanceProjection: balanceProjection
        )
    }

    static let defaultAccountName = "Cuenta principal"

    private func position(
        key: String,
        account: Account?,
        transactions: [Transaction],
        now: Date
    ) -> AccountPosition {
        let latestStatementBalance = transactions
            .compactMap { transaction -> (Date, Decimal)? in
                guard let balance = transaction.balanceAfter else { return nil }
                return (transaction.bookingDate, balance)
            }
            .max { $0.0 < $1.0 }

        let balance: Decimal
        let source: BalanceSource
        let asOf: Date?
        if let account, let currentBalance = account.currentBalance {
            let afterSnapshot = transactions
                .filter { transaction in
                    guard let balanceAsOf = account.balanceAsOf else { return false }
                    return transaction.bookingDate > balanceAsOf && transaction.bookingDate <= now
                }
                .reduce(Decimal.zero) { $0 + $1.amount }
            balance = currentBalance + afterSnapshot
            source = account.balanceSourceRaw == BalanceSource.statement.rawValue ? .statement : .manual
            asOf = account.balanceAsOf
        } else if let latestStatementBalance {
            balance = latestStatementBalance.1
            source = .statement
            asOf = latestStatementBalance.0
        } else {
            balance = transactions.reduce(Decimal.zero) { $0 + $1.amount }
            source = .estimated
            asOf = nil
        }

        let isLiability = account?.isLiability ?? false
        return AccountPosition(
            id: account?.id ?? UUID(uuidString: key) ?? UUID(),
            name: account?.name ?? key,
            balance: balance,
            signedBalance: isLiability ? -balance : balance,
            isLiability: isLiability,
            source: source,
            asOf: asOf
        )
    }

    private func recurringCashflowEstimate(
        transactions: [Transaction],
        categories: [Category],
        now: Date,
        calendar: Calendar
    ) -> RecurringCashflowEstimate {
        // Recurrence must be detected from source movements. Budget entries can
        // split one salary into several reporting lines and make a one-off
        // extraordinary payment look periodic.
        let scope = FinancialReportingScope(now: now, dateBasis: .booking, calendar: calendar)
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let sourceTransactions = uniqueSourceTransactions(
            scope.eligibleTransactions(
                from: transactions,
                classifier: classifier,
                categoryMap: categoryMap
            )
        )
        let entries = sourceTransactions.map {
            FinancialReportingEntry(transaction: $0, date: $0.bookingDate, amount: $0.amount)
        }
        let operatingEntries = entries.filter {
            !isExcludedFromLongTermProjection($0.transaction, categoryMap: categoryMap)
        }

        let currentMonth = startOfMonth(now, calendar: calendar)
        guard let historyStart = calendar.date(byAdding: .month, value: -11, to: currentMonth),
              let historyEnd = calendar.date(byAdding: .month, value: 1, to: currentMonth),
              let recentWindowStart = calendar.date(byAdding: .month, value: -5, to: currentMonth) else {
            return RecurringCashflowEstimate(
                recurringIncome: .zero,
                recurringExpenses: .zero,
                historicalIncomeAverage: .zero,
                historicalExpenseAverage: .zero,
                historyMonths: 0
            )
        }

        let historyEntries = operatingEntries.filter { entry in
            entry.date >= historyStart && entry.date < historyEnd
        }
        let monthKeys = Set(historyEntries.map { startOfMonth($0.date, calendar: calendar) })
        guard !monthKeys.isEmpty else {
            return RecurringCashflowEstimate(
                recurringIncome: .zero,
                recurringExpenses: .zero,
                historicalIncomeAverage: .zero,
                historicalExpenseAverage: .zero,
                historyMonths: 0
            )
        }

        // Keep zero-spend months in the expense baseline. A one-off project
        // should not become a monthly expense just because it happened twice.
        let allHistoryMonths = (0..<12).compactMap {
            calendar.date(byAdding: .month, value: -11 + $0, to: currentMonth)
        }
        var monthlyIncome = Dictionary(uniqueKeysWithValues: allHistoryMonths.map { ($0, Decimal.zero) })
        var monthlyExpenses = Dictionary(uniqueKeysWithValues: allHistoryMonths.map { ($0, Decimal.zero) })
        for entry in historyEntries {
            let month = startOfMonth(entry.date, calendar: calendar)
            if classifier.isIncome(entry.transaction) {
                monthlyIncome[month, default: .zero] += entry.amount
            } else if classifier.isExpense(entry.transaction) {
                monthlyExpenses[month, default: .zero] += absolute(entry.amount)
            }
        }

        let incomeGroups = recurringGroups(
            from: historyEntries.filter { classifier.isIncome($0.transaction) },
            amount: { $0.amount },
            calendar: calendar,
            recentWindowStart: recentWindowStart,
            categoryMap: categoryMap
        )
        let expenseGroups = recurringGroups(
            from: historyEntries.filter { classifier.isExpense($0.transaction) },
            amount: { absolute($0.amount) },
            calendar: calendar,
            recentWindowStart: recentWindowStart,
            categoryMap: categoryMap
        )

        let divisor = Decimal(monthKeys.count)
        let historicalIncomeAverage = monthlyIncome.values.reduce(Decimal.zero, +) / divisor
        let historicalExpenseAverage = monthlyExpenses.values.reduce(Decimal.zero, +) / divisor
        let observedStart = monthKeys.min() ?? recentWindowStart
        let baselineWindowStart = observedStart > recentWindowStart ? observedStart : recentWindowStart

        // Income has no residual component. An occasional loan, withdrawal,
        // refund or transfer must never be promoted to recurring salary.
        //
        // Some banks vary the description of otherwise equivalent salary
        // deposits. If no stable label can be matched, use the median of the
        // already-filtered operating income by month. This keeps an extra
        // salary or other isolated peak from becoming the long-term baseline,
        // while avoiding the misleading 0 EUR baseline when the income is
        // genuine but inconsistently labelled.
        let verifiedRecurringIncome = incomeGroups.reduce(Decimal.zero) { $0 + $1.typicalMonthlyAmount }
        let recentIncomeValues = monthlyIncome
            .filter { $0.key >= baselineWindowStart && $0.value > .zero }
            .map(\.value)
        let observedIncomeValues = monthlyIncome
            .filter { $0.key >= observedStart && $0.value > .zero }
            .map(\.value)
        let incomeFallbackValues = recentIncomeValues.count >= 3
            ? recentIncomeValues
            : observedIncomeValues
        let recurringIncome = verifiedRecurringIncome > .zero
            ? verifiedRecurringIncome
            : incomeFallbackValues.count >= 3
                ? median(incomeFallbackValues)
                : .zero
        let recurringExpenses = recurringBaseline(
            groups: expenseGroups,
            entries: historyEntries.filter { classifier.isExpense($0.transaction) },
            monthlyTotals: monthlyExpenses,
            baselineWindowStart: baselineWindowStart,
            calendar: calendar,
            categoryMap: categoryMap
        )

        return RecurringCashflowEstimate(
            recurringIncome: recurringIncome,
            recurringExpenses: recurringExpenses,
            historicalIncomeAverage: historicalIncomeAverage,
            historicalExpenseAverage: historicalExpenseAverage,
            historyMonths: monthKeys.count
        )
    }

    private func uniqueSourceTransactions(_ transactions: [Transaction]) -> [Transaction] {
        var seenKeys = Set<String>()
        return transactions.filter { transaction in
            guard !isDuplicateForProjection(transaction) else { return false }
            let fingerprint = transaction.fingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = fingerprint.isEmpty ? "id:\(transaction.id.uuidString)" : "fingerprint:\(fingerprint)"
            return seenKeys.insert(key).inserted
        }
    }

    private func isDuplicateForProjection(_ transaction: Transaction) -> Bool {
        if transaction.duplicateReviewStatusRaw == DuplicateReviewStatus.pending.rawValue {
            return true
        }

        guard transaction.duplicateGroupID != nil else { return false }
        return transaction.duplicateReviewStatusRaw != DuplicateReviewStatus.dismissed.rawValue
    }

    private func isExcludedFromLongTermProjection(
        _ transaction: Transaction,
        categoryMap: [UUID: String]
    ) -> Bool {
        let text = normalizedProjectionText(for: transaction)

        if classifier.isIncome(transaction) {
            let categoryKey = projectionCategoryKey(for: transaction, categoryMap: categoryMap)
            let payrollSignals = ["NOMINA", "SALARIO", "SALARY", "PAYROLL"]
            let hardNonOperatingIncomeSignals = [
                "PRESTAMO", "DISPOSICION", "CREDITO", "LOAN", "MUTUO",
                "INVERSION", "FONDO", "ACCIONES", "VALORES",
                "REEMBOLSO", "DEVOLUCION", "REFUND", "CASHBACK", "BONIFICACION"
            ]
            // Some banks prefix payroll with a transfer label. Keep it when
            // the economic source is clearly payroll. An explicit income
            // category is also enough to validate a bank's generic transfer
            // label, but never overrides a hard loan/investment signal.
            if containsAny(text, signals: payrollSignals) || categoryKey == "INGRESOS" {
                return containsAny(text, signals: hardNonOperatingIncomeSignals)
            }
            return containsAny(text, signals: hardNonOperatingIncomeSignals + [
                "TRANSFERENCIA", "TRANSF", "TRASPASO", "BIZUM", "ABONO"
            ])
        }

        guard classifier.isExpense(transaction) else { return true }
        return containsAny(text, signals: [
            "INVERSION", "FONDO", "ACCIONES", "VALORES", "DEPOSITO",
            "OBRA", "REFORMA", "INSTALACION", "INSTALACIONES"
        ])
    }

    private func normalizedProjectionText(for transaction: Transaction) -> String {
        [
            transaction.rawDescription,
            transaction.cleanedDescription,
            transaction.merchantCanonicalName ?? ""
        ]
        .joined(separator: " ")
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .uppercased()
        .replacingOccurrences(of: "[^A-Z0-9]+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(_ text: String, signals: [String]) -> Bool {
        signals.contains { text.contains($0) }
    }

    private func recurringGroups(
        from entries: [FinancialReportingEntry],
        amount: (FinancialReportingEntry) -> Decimal,
        calendar: Calendar,
        recentWindowStart: Date,
        categoryMap: [UUID: String]
    ) -> [RecurringCashflowGroup] {
        let keyedEntries = entries.compactMap { entry -> (key: String, entry: FinancialReportingEntry)? in
            guard let key = recurringKey(for: entry.transaction) else { return nil }
            return (key: key, entry: entry)
        }

        return Dictionary(grouping: keyedEntries, by: \.key)
            .compactMap { _, keyedItems in
                let items = keyedItems.map(\.entry)
                let monthlyAmounts = items.reduce(into: [Date: Decimal]()) { result, entry in
                    let month = startOfMonth(entry.date, calendar: calendar)
                    result[month, default: .zero] += amount(entry)
                }
                let recentMonths = Set(
                    items
                        .map { startOfMonth($0.date, calendar: calendar) }
                        .filter { $0 >= recentWindowStart }
                )
                guard items.count >= 3,
                      monthlyAmounts.count >= 3,
                      recentMonths.count >= 3 else {
                    return nil
                }

                let typicalMonthlyAmount = median(Array(monthlyAmounts.values))
                guard typicalMonthlyAmount > .zero else { return nil }

                // A payment that is one or two times larger than the normal
                // series (for example an extra salary) may be present, but a
                // highly unstable series is not a long-term commitment.
                let stableMonthCount = monthlyAmounts.values.filter {
                    $0 >= typicalMonthlyAmount / Decimal(2) &&
                    $0 <= typicalMonthlyAmount * Decimal(3) / Decimal(2)
                }.count
                guard stableMonthCount >= max(2, monthlyAmounts.count - 1) else {
                    return nil
                }

                let categoryKeys = Set(
                    items.map { projectionCategoryKey(for: $0.transaction, categoryMap: categoryMap) }
                )

                return RecurringCashflowGroup(
                    monthlyAmounts: monthlyAmounts,
                    typicalMonthlyAmount: typicalMonthlyAmount,
                    categoryKey: categoryKeys.count == 1 ? categoryKeys.first : nil,
                    isTemporary: items.allSatisfy {
                        isTemporaryExpense($0.transaction, categoryMap: categoryMap)
                    }
                )
            }
    }

    private func recurringBaseline(
        groups: [RecurringCashflowGroup],
        entries: [FinancialReportingEntry],
        monthlyTotals: [Date: Decimal],
        baselineWindowStart: Date,
        calendar: Calendar,
        categoryMap: [UUID: String]
    ) -> Decimal {
        let recurringGroups = groups.filter { !$0.isTemporary }
        let recurringTotal = recurringGroups.reduce(Decimal.zero) { $0 + $1.typicalMonthlyAmount }
        guard !monthlyTotals.isEmpty else { return recurringTotal }

        var recognizedByMonth: [Date: Decimal] = [:]
        for group in recurringGroups {
            for (month, amount) in group.monthlyAmounts {
                recognizedByMonth[month, default: .zero] += amount
            }
        }

        var temporaryTotals = Dictionary(uniqueKeysWithValues: monthlyTotals.keys.map { ($0, Decimal.zero) })
        var nonTemporaryTotals = monthlyTotals
        for entry in entries {
            guard isTemporaryExpense(entry.transaction, categoryMap: categoryMap) else { continue }
            let month = startOfMonth(entry.date, calendar: calendar)
            let amount = absolute(entry.amount)
            temporaryTotals[month, default: .zero] += amount
            nonTemporaryTotals[month, default: .zero] -= amount
        }

        let residuals = nonTemporaryTotals
            .filter { $0.key >= baselineWindowStart }
            .map { month, total in
                max(total - recognizedByMonth[month, default: .zero], .zero)
            }

        let temporaryRunRate = lowerHalfMedian(
            temporaryTotals
                .filter { $0.key >= baselineWindowStart }
                .map(\.value)
        )
        return recurringTotal + median(residuals) + temporaryRunRate
    }

    private func projectionCategoryKey(
        for transaction: Transaction,
        categoryMap: [UUID: String]
    ) -> String {
        if let categoryID = transaction.categoryID,
           let categoryName = categoryMap[categoryID] {
            return normalizedSeriesLabel(categoryName)
        }

        return isTemporarySetupExpense(transaction) ? "SETUP" : "OTHER"
    }

    private func isTemporaryExpense(
        _ transaction: Transaction,
        categoryMap: [UUID: String]
    ) -> Bool {
        let categoryKey = projectionCategoryKey(for: transaction, categoryMap: categoryMap)
        return isTemporaryExpenseCategory(categoryKey) || isTemporarySetupExpense(transaction)
    }

    private func isTemporaryExpenseCategory(_ categoryKey: String?) -> Bool {
        guard let categoryKey else { return false }
        return categoryKey == "COMPRAS" || categoryKey == "SETUP"
    }

    private func isTemporarySetupExpense(_ transaction: Transaction) -> Bool {
        containsAny(normalizedProjectionText(for: transaction), signals: [
            "IKEA", "LEROY MERLIN", "MUEBLE", "MUEBLES", "ELECTRODOMESTICO",
            "ELECTRODOMESTICOS", "INSTALACION", "INSTALACIONES", "FERRETERIA",
            "DECORACION", "REFORMA", "OBRA", "CONFORAMA", "BRICOMART",
            "BAUHAUS", "JYSK"
        ])
    }

    private func recurringKey(for transaction: Transaction) -> String? {
        let merchant = normalizedSeriesLabel(transaction.merchantCanonicalName)
        let description = normalizedSeriesLabel(
            transaction.cleanedDescription.isEmpty ? transaction.rawDescription : transaction.cleanedDescription
        )
        let candidate: String
        if !merchant.isEmpty && !isGenericSeriesLabel(merchant) {
            candidate = merchant
        } else if !description.isEmpty && !isGenericSeriesLabel(description) {
            candidate = description
        } else {
            return nil
        }
        return candidate
    }

    private func normalizedSeriesLabel(_ value: String?) -> String {
        guard let value else { return "" }
        return value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isGenericSeriesLabel(_ label: String) -> Bool {
        let words = Set(label.split(separator: " ").map(String.init))
        let genericWords = [
            "TRANSFERENCIA", "TRANSF", "TRASPASO", "BIZUM", "ABONO", "RECIBO", "CARGO",
            "DISPOSICION", "MOVIMIENTO", "INGRESO", "PAGO", "COMPRA", "TARJETA"
        ]
        if genericWords.contains(where: words.contains) { return true }
        return words.contains("S") && words.contains("ORD")
    }

    private func median(_ values: [Decimal]) -> Decimal {
        guard !values.isEmpty else { return .zero }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / Decimal(2)
        }
        return sorted[middle]
    }

    private func lowerHalfMedian(_ values: [Decimal]) -> Decimal {
        guard !values.isEmpty else { return .zero }
        let sorted = values.sorted()
        let lowerHalfCount = max(1, (sorted.count + 1) / 2)
        return median(Array(sorted.prefix(lowerHalfCount)))
    }

    private func absolute(_ value: Decimal) -> Decimal {
        value < .zero ? -value : value
    }

    private func project(_ goal: SavingsGoal, now: Date, calendar: Calendar) -> SavingsGoalProjection {
        let monthsToTarget: Int
        if let targetDate = goal.targetDate {
            let components = calendar.dateComponents([.year, .month], from: now, to: targetDate)
            monthsToTarget = max(1, (components.month ?? 0) + (components.year ?? 0) * 12)
        } else {
            monthsToTarget = 12
        }
        let projectedAmount = goal.allocatedAmount + goal.monthlyContribution * Decimal(monthsToTarget)
        return SavingsGoalProjection(
            id: goal.id,
            name: goal.name,
            kind: goal.kind,
            allocatedAmount: goal.allocatedAmount,
            targetAmount: goal.targetAmount,
            monthlyContribution: goal.monthlyContribution,
            projectedAmount: projectedAmount,
            targetDate: goal.targetDate,
            monthsToTarget: monthsToTarget
        )
    }

    private func makeBalanceProjection(
        totalBalance: Decimal,
        availableBalance: Decimal,
        monthlySavingsAverage: Decimal,
        plannedMonthlyGoalContributions: Decimal,
        now: Date,
        calendar: Calendar
    ) -> [BalanceProjectionPoint] {
        let currentMonth = startOfMonth(now, calendar: calendar)
        return (0...12).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: offset, to: currentMonth) else {
                return nil
            }

            let monthCount = Decimal(offset)
            return BalanceProjectionPoint(
                id: date,
                date: date,
                balance: totalBalance + monthlySavingsAverage * monthCount,
                availableBalance: availableBalance + (monthlySavingsAverage - plannedMonthlyGoalContributions) * monthCount,
                isProjected: offset > 0
            )
        }
    }

    private func accountKey(_ name: String?) -> String {
        guard let name else { return Self.defaultAccountName }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultAccountName : trimmed
    }

    private func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
