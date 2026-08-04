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

struct DashboardSnapshot {
    let monthTitle: String
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let netBalance: Decimal
    let savingsRate: Double
    let categorizedPercentage: Double
    let pendingReviewCount: Int
    let dominantCategoryName: String?
    let expenseDeltaFromPreviousMonth: Decimal
    let expenseDeltaPercentage: Double?
    let topCategories: [DashboardCategoryItem]
    let categoryChanges: [DashboardCategoryItem]
    let trend: [DashboardTrendPoint]
    let monthlyCashflow: [MonthlyCashflowPoint]
    let recentImports: [ImportBatch]
}

struct DashboardInsightService {
    func buildSnapshot(
        transactions: [Transaction],
        categories: [Category],
        recentImports: [ImportBatch],
        locale: Locale
    ) -> DashboardSnapshot? {
        guard let referenceDate = transactions.map(\.accountingDate).max() else {
            return nil
        }

        let calendar = Calendar.current
        let currentMonthStart = startOfMonth(for: referenceDate)
        guard let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart),
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) else {
            return nil
        }

        let validTransactions = transactions.filter { $0.resolvedKind != .transfer }
        let currentMonthTransactions = validTransactions
            .filter {
                $0.accountingDate >= currentMonthStart &&
                $0.accountingDate < nextMonthStart
            }
            .sorted { $0.accountingDate < $1.accountingDate }
        let previousMonthTransactions = validTransactions
            .filter {
                $0.accountingDate >= previousMonthStart &&
                $0.accountingDate < currentMonthStart
            }

        let totalIncome = currentMonthTransactions
            .filter { decimalValue($0.amount) > 0 }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let totalExpenses = currentMonthTransactions
            .filter { decimalValue($0.amount) < 0 }
            .reduce(Decimal.zero) { $0 + absolute($1.amount) }
        let netBalance = totalIncome - totalExpenses
        let savingsRate = totalIncome == .zero ? 0 : doubleValue(netBalance / totalIncome)
        let categorizedCount = currentMonthTransactions.filter { $0.categoryID != nil }.count
        let categorizedPercentage = currentMonthTransactions.isEmpty ? 0 : Double(categorizedCount) / Double(currentMonthTransactions.count)
        let pendingReviewCount = currentMonthTransactions.filter {
            $0.categoryID == nil || $0.needsReview || $0.reviewStatusRaw == ReviewStatus.pending.rawValue
        }.count

        let previousExpenses = previousMonthTransactions
            .filter { decimalValue($0.amount) < 0 }
            .reduce(Decimal.zero) { $0 + absolute($1.amount) }
        let expenseDelta = totalExpenses - previousExpenses
        let expenseDeltaPercentage = previousExpenses == .zero ? nil : doubleValue(expenseDelta / previousExpenses)

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let categoryItems = buildCategoryItems(
            from: currentMonthTransactions,
            comparedTo: previousMonthTransactions,
            categoryMap: categoryMap,
            totalExpenses: totalExpenses
        )
        let trend = buildTrend(from: currentMonthTransactions, locale: locale)
        let monthlyCashflow = buildMonthlyCashflow(
            from: validTransactions,
            currentMonthStart: currentMonthStart,
            nextMonthStart: nextMonthStart,
            locale: locale
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
            dominantCategoryName: categoryItems.first?.name,
            expenseDeltaFromPreviousMonth: expenseDelta,
            expenseDeltaPercentage: expenseDeltaPercentage,
            topCategories: Array(categoryItems.prefix(8)),
            categoryChanges: Array(categoryItems.sorted(by: categoryChangeSort).prefix(8)),
            trend: trend,
            monthlyCashflow: monthlyCashflow,
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
        Dictionary(grouping: transactions.filter { decimalValue($0.amount) < 0 }) { transaction in
            transaction.categoryID.flatMap { categoryMap[$0] } ?? String(localized: "Sin categorizar")
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

    private func buildTrend(from transactions: [Transaction], locale: Locale) -> [DashboardTrendPoint] {
        let grouped = Dictionary(grouping: transactions) { Calendar.current.startOfDay(for: $0.accountingDate) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d MMM"

        return grouped.keys.sorted().map { day in
            let dayTransactions = grouped[day] ?? []
            let income = dayTransactions
                .filter { decimalValue($0.amount) > 0 }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let expense = dayTransactions
                .filter { decimalValue($0.amount) < 0 }
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
        locale: Locale
    ) -> [MonthlyCashflowPoint] {
        let calendar = Calendar.current
        guard let historyStart = calendar.date(byAdding: .month, value: -5, to: currentMonthStart) else {
            return []
        }

        let historyTransactions = transactions.filter {
            $0.accountingDate >= historyStart && $0.accountingDate < nextMonthStart
        }
        guard let firstTransactionDate = historyTransactions.map(\.accountingDate).min() else {
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
                $0.accountingDate >= monthStart && $0.accountingDate < monthEnd
            }
            let income = monthTransactions
                .filter { decimalValue($0.amount) > 0 }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let expense = monthTransactions
                .filter { decimalValue($0.amount) < 0 }
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

    private func decimalValue(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    private func doubleValue(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    private func absolute(_ decimal: Decimal) -> Decimal {
        decimal < 0 ? -decimal : decimal
    }
}
