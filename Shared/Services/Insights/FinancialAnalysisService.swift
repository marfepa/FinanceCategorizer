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
    let sourceMonthCount: Int

    var hasLimitedHistory: Bool {
        sourceMonthCount < 3
    }
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
    let categoryEvolution: [CategoryEvolutionItem]
    let monthlyCashflow: [MonthlyCashflowPoint]
    let netTrend: FinancialTrendDirection
    let netDeltaFromPreviousMonth: Decimal?
    let dataQuality: FinancialDataQuality
    let forecast: ForecastSnapshot
    let recurringExpenses: [RecurringExpenseItem]
}

struct FinancialAnalysisService {
    private let classifier = FinancialMovementClassifier()

    func analyze(
        transactions: [Transaction],
        categories: [Category],
        range: AnalysisTimeRange,
        now: Date = .now,
        dateBasis: DashboardDateBasis = .accounting
    ) -> FinancialAnalysisSnapshot {
        let reportingScope = FinancialReportingScope(now: now, dateBasis: dateBasis)
        let validTransactions = reportingScope.eligibleTransactions(
            from: transactions,
            classifier: classifier
        )
        let anchorMonthStart = reportingScope.activeMonthStart(
            from: transactions,
            classifier: classifier
        )
        let filteredTransactions = reportingScope.transactions(
            from: validTransactions,
            in: range,
            anchoredAt: anchorMonthStart
        )
        let previousTransactions = previousWindowTransactions(
            from: validTransactions,
            for: range,
            anchorMonthStart: anchorMonthStart,
            dateBasis: dateBasis
        )
        let filteredSourceTransactions = reportingScope.transactions(
            from: transactions,
            in: range,
            anchoredAt: anchorMonthStart
        )
        let dataQuality = classifier.dataQuality(for: filteredSourceTransactions)
        let pendingReviewCount = dataQuality.pendingReviewCount

        let totalIncome = filteredTransactions
            .filter(classifier.isIncome)
            .reduce(Decimal.zero) { $0 + $1.amount }

        let totalExpenses = filteredTransactions
            .filter(classifier.isExpense)
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
        let categoryEvolution = buildCategoryEvolution(
            from: filteredTransactions,
            categoryMap: categoryMap
        )
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
            categoryEvolution: categoryEvolution,
            monthlyCashflow: monthlyCashflow,
            netTrend: classifier.trend(for: monthlyCashflow),
            netDeltaFromPreviousMonth: classifier.deltaFromPreviousMonth(for: monthlyCashflow),
            dataQuality: dataQuality,
            forecast: forecast,
            recurringExpenses: recurringExpenses
        )
    }

    private func previousWindowTransactions(
        from allTransactions: [Transaction],
        for range: AnalysisTimeRange,
        anchorMonthStart: Date?,
        dateBasis: DashboardDateBasis
    ) -> [Transaction] {
        guard let monthWindow = range.monthWindow,
              let anchorMonthStart,
              let currentStart = Calendar.current.date(
                  byAdding: .month,
                  value: -(monthWindow - 1),
                  to: anchorMonthStart
              ),
              let previousStart = Calendar.current.date(
                  byAdding: .month,
                  value: -monthWindow,
                  to: currentStart
              ),
              let previousEnd = Calendar.current.date(byAdding: .day, value: -1, to: currentStart) else {
            return []
        }

        let reportingScope = FinancialReportingScope(dateBasis: dateBasis)
        return allTransactions.filter {
            let date = reportingScope.date(for: $0)
            return date >= previousStart && date <= previousEnd
        }
    }

    private func buildCategoryBreakdown(
        transactions: [Transaction],
        previousTransactions: [Transaction],
        categoryMap: [UUID: String],
        totalExpenses: Decimal
    ) -> [CategoryBreakdownItem] {
        let currentExpenses = Dictionary(grouping: transactions.filter(classifier.isExpense)) { transaction in
            classifier.categoryName(for: transaction, categoryMap: categoryMap) ?? "Sin categorizar"
        }.mapValues { $0.reduce(Decimal.zero) { $0 + absolute($1.amount) } }

        let previousExpenses = Dictionary(grouping: previousTransactions.filter(classifier.isExpense)) { transaction in
            classifier.categoryName(for: transaction, categoryMap: categoryMap) ?? "Sin categorizar"
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

    private func buildCategoryEvolution(
        from transactions: [Transaction],
        categoryMap: [UUID: String]
    ) -> [CategoryEvolutionItem] {
        let expenseTransactions = transactions.filter(classifier.isExpense)
        guard let firstDate = expenseTransactions.map(\.accountingDate).min(),
              let lastDate = expenseTransactions.map(\.accountingDate).max() else {
            return []
        }

        let firstMonth = startOfMonth(for: firstDate)
        let lastMonth = startOfMonth(for: lastDate)
        let months = sequenceOfMonths(from: firstMonth, through: lastMonth)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.locale = Locale.current

        let monthlyAmounts = Dictionary(grouping: expenseTransactions) {
            startOfMonth(for: $0.accountingDate)
        }.mapValues { monthTransactions in
            Dictionary(grouping: monthTransactions) { transaction in
                classifier.categoryName(for: transaction, categoryMap: categoryMap) ?? "Sin categorizar"
            }.mapValues { items in
                items.reduce(Decimal.zero) { $0 + absolute($1.amount) }
            }
        }

        let categoryNames = Set(monthlyAmounts.values.flatMap(\.keys))
        return categoryNames.map { categoryName in
            let points = months.map { month in
                CategoryEvolutionPoint(
                    id: "\(categoryName)-\(month.timeIntervalSince1970)",
                    categoryName: categoryName,
                    monthLabel: formatter.string(from: month),
                    startDate: month,
                    amount: monthlyAmounts[month]?[categoryName] ?? .zero
                )
            }
            let latestAmount = points.last?.amount ?? .zero
            let previousAmount = points.dropLast().last?.amount ?? .zero
            let delta = latestAmount - previousAmount
            let deltaPercentage = previousAmount == .zero ? nil : decimalToDouble(delta / previousAmount)
            let isSpiking = delta > .zero &&
                ((previousAmount == .zero && latestAmount > .zero) || (deltaPercentage ?? 0) >= 0.25)

            return CategoryEvolutionItem(
                id: categoryName,
                categoryName: categoryName,
                points: points,
                latestAmount: latestAmount,
                previousAmount: previousAmount,
                deltaFromPreviousMonth: delta,
                deltaPercentage: deltaPercentage,
                isSpiking: isSpiking
            )
        }
        .sorted {
            if $0.latestAmount != $1.latestAmount { return $0.latestAmount > $1.latestAmount }
            return $0.categoryName < $1.categoryName
        }
    }

    private func buildMonthlyCashflow(from transactions: [Transaction]) -> [MonthlyCashflowPoint] {
        let grouped = Dictionary(grouping: transactions, by: { startOfMonth(for: $0.accountingDate) })
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.locale = Locale.current

        return grouped.keys.sorted().map { month in
            let monthTransactions = grouped[month] ?? []
            let income = monthTransactions
                .filter(classifier.isIncome)
                .reduce(Decimal.zero) { $0 + $1.amount }
            let expense = monthTransactions
                .filter(classifier.isExpense)
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
            isNegativeTrend: NSDecimalNumber(decimal: averageMonthlyNet).doubleValue < 0,
            sourceMonthCount: monthlyCashflow.count
        )
    }

    private func buildRecurringExpenses(from transactions: [Transaction]) -> [RecurringExpenseItem] {
        Dictionary(grouping: transactions.filter(classifier.isExpense), by: \.cleanedDescription)
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

    private func sequenceOfMonths(from start: Date, through end: Date) -> [Date] {
        var months: [Date] = []
        var current = start
        while current <= end {
            months.append(current)
            guard let next = Calendar.current.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }
        return months
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
