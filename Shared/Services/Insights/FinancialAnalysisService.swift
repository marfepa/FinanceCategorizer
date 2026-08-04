import Foundation

enum AnalysisTimeRange: String, CaseIterable, Identifiable {
    case month
    case threeMonths
    case sixMonths
    case year
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "1M"
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .year: return "12M"
        case .all: return "All"
        }
    }

    var monthWindow: Int? {
        switch self {
        case .month: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .year: return 12
        case .all: return nil
        }
    }
}

struct CategoryBreakdownItem: Identifiable {
    let id: String
    let categoryName: String
    let amount: Decimal
    let percentage: Double
    let deltaFromPreviousPeriod: Decimal
}

struct MonthlyCashflowPoint: Identifiable {
    let id: String
    let monthLabel: String
    let startDate: Date
    let income: Decimal
    let expense: Decimal
    let net: Decimal
}

struct ForecastSnapshot {
    let averageMonthlyNet: Decimal
    let projectedDelta3Months: Decimal
    let projectedDelta6Months: Decimal
    let projectedDelta12Months: Decimal
    let isNegativeTrend: Bool
}

struct RecurringExpenseItem: Identifiable {
    let id: String
    let concept: String
    let averageAmount: Decimal
    let occurrences: Int
    let latestDate: Date
}

struct FinancialAnalysisSnapshot {
    let range: AnalysisTimeRange
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let netBalance: Decimal
    let savingsRate: Double
    let categorizedPercentage: Double
    let pendingReviewCount: Int
    let categoryBreakdown: [CategoryBreakdownItem]
    let monthlyCashflow: [MonthlyCashflowPoint]
    let forecast: ForecastSnapshot
    let recurringExpenses: [RecurringExpenseItem]
}

struct FinancialAnalysisService {
    func analyze(
        transactions: [Transaction],
        categories: [Category],
        range: AnalysisTimeRange
    ) -> FinancialAnalysisSnapshot {
        let validTransactions = transactions.filter { $0.resolvedKind != .transfer }
        let filteredTransactions = filter(transactions: validTransactions, for: range)
        let previousTransactions = previousWindowTransactions(from: validTransactions, for: range, anchorTransactions: filteredTransactions)
        let pendingReviewCount = filteredTransactions.filter {
            $0.categoryID == nil || $0.needsReview || $0.reviewStatusRaw == ReviewStatus.pending.rawValue
        }.count

        let totalIncome = filteredTransactions
            .filter { NSDecimalNumber(decimal: $0.amount).doubleValue > 0 }
            .reduce(Decimal.zero) { $0 + $1.amount }

        let totalExpenses = filteredTransactions
            .filter { NSDecimalNumber(decimal: $0.amount).doubleValue < 0 }
            .reduce(Decimal.zero) { partial, transaction in
                partial + absolute(transaction.amount)
            }

        let netBalance = totalIncome - totalExpenses
        let savingsRate = totalIncome.isZero ? 0 : decimalToDouble(netBalance / totalIncome)
        let categorizedCount = filteredTransactions.filter { $0.categoryID != nil }.count
        let categorizedPercentage = filteredTransactions.isEmpty ? 0 : Double(categorizedCount) / Double(filteredTransactions.count)

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let categoryBreakdown = buildCategoryBreakdown(
            transactions: filteredTransactions,
            previousTransactions: previousTransactions,
            categoryMap: categoryMap,
            totalExpenses: totalExpenses
        )
        let monthlyCashflow = buildMonthlyCashflow(from: filteredTransactions)
        let forecast = buildForecast(from: monthlyCashflow)
        let recurringExpenses = buildRecurringExpenses(from: filteredTransactions)

        return FinancialAnalysisSnapshot(
            range: range,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            netBalance: netBalance,
            savingsRate: savingsRate,
            categorizedPercentage: categorizedPercentage,
            pendingReviewCount: pendingReviewCount,
            categoryBreakdown: categoryBreakdown,
            monthlyCashflow: monthlyCashflow,
            forecast: forecast,
            recurringExpenses: recurringExpenses
        )
    }

    private func filter(transactions: [Transaction], for range: AnalysisTimeRange) -> [Transaction] {
        guard let monthWindow = range.monthWindow,
              let latestDate = transactions.map(\.accountingDate).max(),
              let startDate = Calendar.current.date(byAdding: .month, value: -(monthWindow - 1), to: startOfMonth(for: latestDate)) else {
            return transactions.sorted { $0.accountingDate < $1.accountingDate }
        }

        return transactions
            .filter { $0.accountingDate >= startDate }
            .sorted { $0.accountingDate < $1.accountingDate }
    }

    private func previousWindowTransactions(
        from allTransactions: [Transaction],
        for range: AnalysisTimeRange,
        anchorTransactions: [Transaction]
    ) -> [Transaction] {
        guard let monthWindow = range.monthWindow,
              let latestDate = anchorTransactions.map(\.accountingDate).max(),
              let currentStart = Calendar.current.date(byAdding: .month, value: -(monthWindow - 1), to: startOfMonth(for: latestDate)),
              let previousStart = Calendar.current.date(byAdding: .month, value: -monthWindow, to: currentStart),
              let previousEnd = Calendar.current.date(byAdding: .day, value: -1, to: currentStart) else {
            return []
        }

        return allTransactions.filter { $0.accountingDate >= previousStart && $0.accountingDate <= previousEnd }
    }

    private func buildCategoryBreakdown(
        transactions: [Transaction],
        previousTransactions: [Transaction],
        categoryMap: [UUID: String],
        totalExpenses: Decimal
    ) -> [CategoryBreakdownItem] {
        let currentExpenses = Dictionary(grouping: transactions.filter { NSDecimalNumber(decimal: $0.amount).doubleValue < 0 }) { transaction in
            transaction.categoryID.flatMap { categoryMap[$0] } ?? "Sin categorizar"
        }.mapValues { $0.reduce(Decimal.zero) { $0 + absolute($1.amount) } }

        let previousExpenses = Dictionary(grouping: previousTransactions.filter { NSDecimalNumber(decimal: $0.amount).doubleValue < 0 }) { transaction in
            transaction.categoryID.flatMap { categoryMap[$0] } ?? "Sin categorizar"
        }.mapValues { $0.reduce(Decimal.zero) { $0 + absolute($1.amount) } }

        return currentExpenses
            .map { name, amount in
                let percentage = totalExpenses.isZero ? 0 : decimalToDouble(amount / totalExpenses)
                let previous = previousExpenses[name] ?? .zero
                return CategoryBreakdownItem(
                    id: name,
                    categoryName: name,
                    amount: amount,
                    percentage: percentage,
                    deltaFromPreviousPeriod: amount - previous
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    private func buildMonthlyCashflow(from transactions: [Transaction]) -> [MonthlyCashflowPoint] {
        let grouped = Dictionary(grouping: transactions, by: { startOfMonth(for: $0.accountingDate) })
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.locale = Locale.current

        return grouped.keys.sorted().map { month in
            let monthTransactions = grouped[month] ?? []
            let income = monthTransactions
                .filter { NSDecimalNumber(decimal: $0.amount).doubleValue > 0 }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let expense = monthTransactions
                .filter { NSDecimalNumber(decimal: $0.amount).doubleValue < 0 }
                .reduce(Decimal.zero) { $0 + absolute($1.amount) }

            return MonthlyCashflowPoint(
                id: formatter.string(from: month),
                monthLabel: formatter.string(from: month),
                startDate: month,
                income: income,
                expense: expense,
                net: income - expense
            )
        }
    }

    private func buildForecast(from monthlyCashflow: [MonthlyCashflowPoint]) -> ForecastSnapshot {
        let averageMonthlyNet: Decimal
        if monthlyCashflow.isEmpty {
            averageMonthlyNet = .zero
        } else {
            let total = monthlyCashflow.reduce(Decimal.zero) { $0 + $1.net }
            averageMonthlyNet = total / Decimal(monthlyCashflow.count)
        }

        return ForecastSnapshot(
            averageMonthlyNet: averageMonthlyNet,
            projectedDelta3Months: averageMonthlyNet * Decimal(3),
            projectedDelta6Months: averageMonthlyNet * Decimal(6),
            projectedDelta12Months: averageMonthlyNet * Decimal(12),
            isNegativeTrend: NSDecimalNumber(decimal: averageMonthlyNet).doubleValue < 0
        )
    }

    private func buildRecurringExpenses(from transactions: [Transaction]) -> [RecurringExpenseItem] {
        Dictionary(grouping: transactions.filter { NSDecimalNumber(decimal: $0.amount).doubleValue < 0 }, by: \.cleanedDescription)
            .compactMap { concept, items in
                guard items.count >= 2 else { return nil }
                let averageAmount = items.reduce(Decimal.zero) { $0 + absolute($1.amount) } / Decimal(items.count)
                let latestDate = items.map(\.bookingDate).max() ?? .now
                return RecurringExpenseItem(
                    id: concept,
                    concept: items.first?.rawDescription ?? concept,
                    averageAmount: averageAmount,
                    occurrences: items.count,
                    latestDate: latestDate
                )
            }
            .sorted { $0.averageAmount > $1.averageAmount }
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private func decimalToDouble(_ decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    private func absolute(_ decimal: Decimal) -> Decimal {
        decimal < 0 ? -decimal : decimal
    }
}

private extension Decimal {
    var isZero: Bool { self == .zero }
}
