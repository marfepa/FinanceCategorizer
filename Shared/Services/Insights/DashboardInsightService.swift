import Foundation

struct DashboardCategoryItem: Identifiable {
    let id: String
    let name: String
    let amount: Decimal
    let share: Double
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
    let trend: [DashboardTrendPoint]
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

        let currentMonthTransactions = transactions
            .filter {
                $0.resolvedKind != .transfer &&
                $0.accountingDate >= currentMonthStart &&
                $0.accountingDate < nextMonthStart
            }
            .sorted { $0.accountingDate < $1.accountingDate }
        let previousMonthTransactions = transactions
            .filter {
                $0.resolvedKind != .transfer &&
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
        let topCategories = buildTopCategories(
            from: currentMonthTransactions,
            categoryMap: categoryMap,
            totalExpenses: totalExpenses,
            locale: locale
        )
        let trend = buildTrend(from: currentMonthTransactions, locale: locale)

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
            dominantCategoryName: topCategories.first?.name,
            expenseDeltaFromPreviousMonth: expenseDelta,
            expenseDeltaPercentage: expenseDeltaPercentage,
            topCategories: Array(topCategories.prefix(5)),
            trend: trend,
            recentImports: Array(recentImports.prefix(4))
        )
    }

    private func buildTopCategories(
        from transactions: [Transaction],
        categoryMap: [UUID: String],
        totalExpenses: Decimal,
        locale: Locale
    ) -> [DashboardCategoryItem] {
        Dictionary(grouping: transactions.filter { decimalValue($0.amount) < 0 }) { transaction in
            transaction.categoryID.flatMap { categoryMap[$0] } ?? String(localized: "Sin categorizar")
        }
        .mapValues { items in
            items.reduce(Decimal.zero) { $0 + absolute($1.amount) }
        }
        .map { name, amount in
            DashboardCategoryItem(
                id: name,
                name: name,
                amount: amount,
                share: totalExpenses == .zero ? 0 : doubleValue(amount / totalExpenses)
            )
        }
        .sorted { $0.amount > $1.amount }
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
