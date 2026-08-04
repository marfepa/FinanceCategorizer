import Foundation

struct DashboardCategoryItem: Identifiable {
    let id: String
    let name: String
    let amount: Decimal
    let share: Double
    let previousAmount: Decimal
    let deltaFromPreviousMonth: Decimal
    let deltaPercentage: Double?
}
struct DashboardTrendPoint: Identifiable {
    let id: String
    let date: Date
    let dayLabel: String
    let income: Decimal
    let expense: Decimal
    let net: Decimal
}

enum DashboardDateBasis {
    case booking
    case accounting
}

struct DashboardSnapshot {
    let monthTitle: String
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let netBalance: Decimal
    let savingsRate: Double
    let categorizedPercentage: Double
    let pendingReviewCount: Int
    let uncategorizedExpenseCount: Int
    let uncategorizedExpenseAmount: Decimal
    let dominantCategoryName: String?
    let expenseDeltaFromPreviousMonth: Decimal
    let expenseDeltaPercentage: Double?
    let topCategories: [DashboardCategoryItem]
    let categoryChanges: [DashboardCategoryItem]
    let trend: [DashboardTrendPoint]
    let monthlyCashflow: [MonthlyCashflowPoint]
    let netTrend: FinancialTrendDirection
    let netDeltaFromPreviousMonth: Decimal?
    let dataQuality: FinancialDataQuality
    let recentImports: [ImportBatch]
}

struct DashboardInsightService {
    private let classifier = FinancialMovementClassifier()

    func buildSnapshot(
        transactions: [Transaction],
        categories: [Category],
        recentImports: [ImportBatch],
        locale: Locale,
        now: Date = .now,
        dateBasis: DashboardDateBasis = .accounting
    ) -> DashboardSnapshot? {
        // The dashboard follows the accounting month used by the app's
        // reporting rules. A payroll booked on 30/07 therefore belongs to
        // August when the configured payroll cutoff moves it forward.
        let validTransactions = transactions.filter(classifier.isIncluded)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let nonFutureTransactions = validTransactions.filter {
            calendar.startOfDay(for: dashboardDate(for: $0, basis: dateBasis)) <= today
        }
        guard let latestKnownDate = nonFutureTransactions.map({ dashboardDate(for: $0, basis: dateBasis) }).max() else {
            return nil
        }

        let calendarMonthStart = startOfMonth(for: today)
        let calendarMonthEnd = calendar.date(byAdding: .month, value: 1, to: calendarMonthStart)
        let currentMonthStart: Date
        if nonFutureTransactions.contains(where: {
            let date = dashboardDate(for: $0, basis: dateBasis)
            return date >= calendarMonthStart &&
                date < (calendarMonthEnd ?? .distantFuture)
        }) {
            currentMonthStart = calendarMonthStart
        } else {
            currentMonthStart = startOfMonth(for: latestKnownDate)
        }

        guard let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart),
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) else {
            return nil
        }

        let currentMonthTransactions = validTransactions
            .filter {
                let date = dashboardDate(for: $0, basis: dateBasis)
                return date >= currentMonthStart &&
                    date < nextMonthStart &&
                    calendar.startOfDay(for: date) <= today
            }
            .sorted { dashboardDate(for: $0, basis: dateBasis) < dashboardDate(for: $1, basis: dateBasis) }
        let currentMonthSourceTransactions = transactions.filter {
            let date = dashboardDate(for: $0, basis: dateBasis)
            return date >= currentMonthStart &&
                date < nextMonthStart &&
                calendar.startOfDay(for: date) <= today
        }
        let previousMonthTransactions = validTransactions
            .filter {
                let date = dashboardDate(for: $0, basis: dateBasis)
                return date >= previousMonthStart &&
                    date < currentMonthStart &&
                    calendar.startOfDay(for: date) <= today
            }

        let totalIncome = currentMonthTransactions
            .filter(isIncome)
            .reduce(Decimal.zero) { $0 + $1.amount }
        let totalExpenses = currentMonthTransactions
            .filter(isExpense)
            .reduce(Decimal.zero) { $0 + absolute($1.amount) }
        let netBalance = totalIncome - totalExpenses
        let savingsRate = totalIncome == .zero ? 0 : doubleValue(netBalance / totalIncome)
        let categorizedCount = currentMonthTransactions.filter { $0.categoryID != nil }.count
        let categorizedPercentage = currentMonthTransactions.isEmpty ? 0 : Double(categorizedCount) / Double(currentMonthTransactions.count)
        let dataQuality = classifier.dataQuality(for: currentMonthSourceTransactions)
        let pendingReviewCount = dataQuality.pendingReviewCount

        let previousExpenses = previousMonthTransactions
            .filter(isExpense)
            .reduce(Decimal.zero) { $0 + absolute($1.amount) }
        let expenseDelta = totalExpenses - previousExpenses
        let expenseDeltaPercentage = previousExpenses == .zero ? nil : doubleValue(expenseDelta / previousExpenses)

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let uncategorizedExpenses = currentMonthTransactions.filter {
            isExpense($0) && storedCategoryName(for: $0, categoryMap: categoryMap) == nil
        }
        let categoryItems = buildCategoryItems(
            from: currentMonthTransactions,
            comparedTo: previousMonthTransactions,
            categoryMap: categoryMap,
            totalExpenses: totalExpenses
        )
        let trend = buildTrend(from: currentMonthTransactions, locale: locale, dateBasis: dateBasis)
        let monthlyCashflow = buildMonthlyCashflow(
            from: validTransactions,
            currentMonthStart: currentMonthStart,
            nextMonthStart: nextMonthStart,
            locale: locale,
            dateBasis: dateBasis,
            today: today
        )

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLLL yyyy"

        return DashboardSnapshot(
            monthTitle: formatter.string(from: currentMonthStart).capitalized,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            netBalance: netBalance,
            savingsRate: savingsRate,
            categorizedPercentage: categorizedPercentage,
            pendingReviewCount: pendingReviewCount,
            uncategorizedExpenseCount: uncategorizedExpenses.count,
            uncategorizedExpenseAmount: uncategorizedExpenses.reduce(Decimal.zero) { $0 + absolute($1.amount) },
            dominantCategoryName: categoryItems.first?.name,
            expenseDeltaFromPreviousMonth: expenseDelta,
            expenseDeltaPercentage: expenseDeltaPercentage,
            topCategories: Array(categoryItems.prefix(8)),
            categoryChanges: Array(categoryItems.sorted(by: categoryChangeSort).prefix(8)),
            trend: trend,
            monthlyCashflow: monthlyCashflow,
            netTrend: classifier.trend(for: monthlyCashflow),
            netDeltaFromPreviousMonth: classifier.deltaFromPreviousMonth(for: monthlyCashflow),
            dataQuality: dataQuality,
            recentImports: Array(recentImports.prefix(4))
        )
    }

    private func buildCategoryItems(
        from transactions: [Transaction],
        comparedTo previousTransactions: [Transaction],
        categoryMap: [UUID: String],
        totalExpenses: Decimal
    ) -> [DashboardCategoryItem] {
        let currentAmounts = amountsByCategory(from: transactions, categoryMap: categoryMap)
        let previousAmounts = amountsByCategory(from: previousTransactions, categoryMap: categoryMap)

        return currentAmounts
            .map { name, amount in
                let previousAmount = previousAmounts[name] ?? .zero
                let delta = amount - previousAmount
                return DashboardCategoryItem(
                    id: name,
                    name: name,
                    amount: amount,
                    share: totalExpenses == .zero ? 0 : doubleValue(amount / totalExpenses),
                    previousAmount: previousAmount,
                    deltaFromPreviousMonth: delta,
                    deltaPercentage: previousAmount == .zero ? nil : doubleValue(delta / previousAmount)
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    private func amountsByCategory(from transactions: [Transaction], categoryMap: [UUID: String]) -> [String: Decimal] {
        Dictionary(grouping: transactions.filter(isExpense)) { transaction in
            categoryName(for: transaction, categoryMap: categoryMap) ?? String(localized: "Sin categorizar")
        }
        .mapValues { items in
            items.reduce(Decimal.zero) { $0 + absolute($1.amount) }
        }
    }

    private func categoryChangeSort(_ lhs: DashboardCategoryItem, _ rhs: DashboardCategoryItem) -> Bool {
        if lhs.deltaFromPreviousMonth != rhs.deltaFromPreviousMonth {
            return lhs.deltaFromPreviousMonth > rhs.deltaFromPreviousMonth
        }
        return lhs.amount > rhs.amount
    }

    private func buildTrend(
        from transactions: [Transaction],
        locale: Locale,
        dateBasis: DashboardDateBasis
    ) -> [DashboardTrendPoint] {
        let grouped = Dictionary(grouping: transactions) {
            Calendar.current.startOfDay(for: dashboardDate(for: $0, basis: dateBasis))
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d MMM"

        return grouped.keys.sorted().map { day in
            let dayTransactions = grouped[day] ?? []
            let income = dayTransactions
                .filter(isIncome)
                .reduce(Decimal.zero) { $0 + $1.amount }
            let expense = dayTransactions
                .filter(isExpense)
                .reduce(Decimal.zero) { $0 + absolute($1.amount) }

            return DashboardTrendPoint(
                id: formatter.string(from: day),
                date: day,
                dayLabel: formatter.string(from: day),
                income: income,
                expense: expense,
                net: income - expense
            )
        }
    }

    private func buildMonthlyCashflow(
        from transactions: [Transaction],
        currentMonthStart: Date,
        nextMonthStart: Date,
        locale: Locale,
        dateBasis: DashboardDateBasis,
        today: Date
    ) -> [MonthlyCashflowPoint] {
        let calendar = Calendar.current
        guard let historyStart = calendar.date(byAdding: .month, value: -5, to: currentMonthStart) else {
            return []
        }

        let historyTransactions = transactions.filter {
            let date = dashboardDate(for: $0, basis: dateBasis)
            return date >= historyStart &&
                date < nextMonthStart &&
                Calendar.current.startOfDay(for: date) <= today
        }
        guard let firstTransactionDate = historyTransactions
            .map({ dashboardDate(for: $0, basis: dateBasis) })
            .min() else {
            return []
        }

        let firstMonth = max(historyStart, startOfMonth(for: firstTransactionDate))
        let months = sequenceOfMonths(from: firstMonth, through: currentMonthStart, calendar: calendar)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLL yy"

        return months.map { monthStart in
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            let monthTransactions = historyTransactions.filter {
                let date = dashboardDate(for: $0, basis: dateBasis)
                return date >= monthStart && date < monthEnd
            }
            let income = monthTransactions
                .filter(isIncome)
                .reduce(Decimal.zero) { $0 + $1.amount }
            let expense = monthTransactions
                .filter(isExpense)
                .reduce(Decimal.zero) { $0 + absolute($1.amount) }

            return MonthlyCashflowPoint(
                id: String(monthStart.timeIntervalSince1970),
                monthLabel: formatter.string(from: monthStart),
                startDate: monthStart,
                income: income,
                expense: expense,
                net: income - expense
            )
        }
    }

    private func sequenceOfMonths(from start: Date, through end: Date, calendar: Calendar) -> [Date] {
        var months: [Date] = []
        var current = start

        while current <= end {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else {
                break
            }
            current = next
        }

        return months
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private func dashboardDate(for transaction: Transaction, basis: DashboardDateBasis) -> Date {
        switch basis {
        case .booking:
            return transaction.bookingDate
        case .accounting:
            return transaction.accountingDate
        }
    }

    private func decimalValue(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    private func doubleValue(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    private func absolute(_ decimal: Decimal) -> Decimal {
        decimal < 0 ? -decimal : decimal
    }

    private func isIncome(_ transaction: Transaction) -> Bool {
        classifier.isIncome(transaction)
    }

    private func isExpense(_ transaction: Transaction) -> Bool {
        classifier.isExpense(transaction)
    }

    private func storedCategoryName(for transaction: Transaction, categoryMap: [UUID: String]) -> String? {
        guard let categoryID = transaction.categoryID else { return nil }
        return categoryMap[categoryID]
    }

    private func categoryName(for transaction: Transaction, categoryMap: [UUID: String]) -> String? {
        classifier.categoryName(for: transaction, categoryMap: categoryMap)
    }
}
