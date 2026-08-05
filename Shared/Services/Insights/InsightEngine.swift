import Foundation

@MainActor
final class InsightEngine {
    private let transactionRepository: TransactionRepository
    private let categoryRepository: CategoryRepository
    private let insightRepository: InsightRepository

    init(
        transactionRepository: TransactionRepository,
        categoryRepository: CategoryRepository,
        insightRepository: InsightRepository
    ) {
        self.transactionRepository = transactionRepository
        self.categoryRepository = categoryRepository
        self.insightRepository = insightRepository
    }

    func refreshInsights(language: AppLanguage) async throws {
        let allTransactions = try transactionRepository.fetchAll()
        let categories = try categoryRepository.fetchAll()
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let classifier = FinancialMovementClassifier()
        let transactions = allTransactions.filter {
            classifier.isIncluded($0, categoryMap: categoryMap)
        }
        var insights: [Insight] = []

        let recentCutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? .distantPast
        let recentExpenses = transactions.filter { $0.amount < 0 && $0.accountingDate >= recentCutoff }
        let groupedByCategory = Dictionary(grouping: recentExpenses) { tx in
            tx.categoryID.flatMap { categoryMap[$0] } ?? String(localized: "Sin categorizar")
        }
        if let topCategory = groupedByCategory.max(by: { lhs, rhs in
            lhs.value.reduce(Decimal.zero) { $0 + absolute($1.amount) } < rhs.value.reduce(Decimal.zero) { $0 + absolute($1.amount) }
        }) {
            let amount = topCategory.value.reduce(Decimal.zero) { $0 + absolute($1.amount) }
            insights.append(
                Insight(
                    title: language.localized("insights.topPressure.title"),
                    body: language.localized("insights.topPressure.body", topCategory.key),
                    severityRaw: InsightSeverity.medium.rawValue,
                    estimatedMonthlyImpact: amount,
                    categoryID: topCategory.value.first?.categoryID
                )
            )
        }

        let recurring = Dictionary(grouping: recentExpenses, by: \.merchantCanonicalName)
            .compactMap { merchant, items -> Insight? in
                guard let merchant, items.count >= 2 else { return nil }
                let average = items.reduce(Decimal.zero) { $0 + absolute($1.amount) } / Decimal(items.count)
                return Insight(
                    title: language.localized("insights.recurring.title"),
                    body: language.localized("insights.recurring.body", merchant),
                    severityRaw: InsightSeverity.low.rawValue,
                    estimatedMonthlyImpact: average,
                    categoryID: items.first?.categoryID
                )
            }

        insights.append(contentsOf: recurring.prefix(3))
        
        // Advanced Insights
        if let anomalies = detectAnomalies(transactions: transactions, categories: categories, language: language) {
            insights.append(contentsOf: anomalies)
        }
        
        if let incomeGap = detectIncomeGap(transactions: transactions, language: language) {
            insights.append(incomeGap)
        }
        
        if let streak = calculateSavingsStreak(transactions: transactions, language: language) {
            insights.append(streak)
        }

        try insightRepository.replaceAll(with: insights)
    }

    private func detectAnomalies(transactions: [Transaction], categories: [Category], language: AppLanguage) -> [Insight]? {
        let calendar = Calendar.current
        let today = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let last6Months = calendar.date(byAdding: .month, value: -6, to: monthStart) ?? Date.distantPast
        
        let historicalTx = transactions.filter { $0.amount < 0 && $0.bookingDate < monthStart && $0.bookingDate > last6Months }
        let currentMonthTx = transactions.filter { $0.amount < 0 && $0.bookingDate >= monthStart }
        
        var anomalies: [Insight] = []
        
        for category in categories {
            let historicalAmounts = historicalTx.filter { $0.categoryID == category.id }.map { absolute($0.amount) }
            guard !historicalAmounts.isEmpty else { continue }
            
            let mean = historicalAmounts.reduce(0, +) / Decimal(historicalAmounts.count)
            let currentAmounts = currentMonthTx.filter { $0.categoryID == category.id }.map { absolute($0.amount) }
            
            for amount in currentAmounts {
                if amount > mean * 2.5 && amount > 100 { // 2.5x mean and significant amount
                    anomalies.append(Insight(
                        title: language.localized("insights.anomaly.title"),
                        body: language.localized("insights.anomaly.body", category.name, language.formatNumber(amount)),
                        severityRaw: InsightSeverity.high.rawValue,
                        estimatedMonthlyImpact: amount - mean,
                        categoryID: category.id
                    ))
                }
            }
        }
        return anomalies.isEmpty ? nil : Array(anomalies.prefix(2))
    }

    private func detectIncomeGap(transactions: [Transaction], language: AppLanguage) -> Insight? {
        let cutoffDay = UserDefaults.standard.integer(forKey: "payrollCutoffDay") == 0 ? 25 : UserDefaults.standard.integer(forKey: "payrollCutoffDay")
        let today = Date()
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: today)
        
        guard currentDay > cutoffDay else { return nil }
        
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let hasIncome = transactions.contains { tx in
            tx.amount > 0 && tx.bookingDate >= monthStart && (tx.cleanedDescription.localizedCaseInsensitiveContains("nomina") || tx.cleanedDescription.localizedCaseInsensitiveContains("salary"))
        }
        
        if !hasIncome {
            return Insight(
                title: language.localized("insights.incomeGap.title"),
                body: language.localized("insights.incomeGap.body", Int64(cutoffDay)),
                severityRaw: InsightSeverity.high.rawValue,
                estimatedMonthlyImpact: 0,
                categoryID: nil
            )
        }
        return nil
    }

    private func calculateSavingsStreak(transactions: [Transaction], language: AppLanguage) -> Insight? {
        let calendar = Calendar.current
        let today = Date()
        var currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        var streak = 0
        
        for _ in 0..<12 {
            guard let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) else { break }
            let monthTransactions = transactions.filter { $0.bookingDate >= previousMonthStart && $0.bookingDate < currentMonthStart }
            let balance = monthTransactions.reduce(Decimal.zero) { $0 + $1.amount }
            
            if balance > 0 {
                streak += 1
                currentMonthStart = previousMonthStart
            } else {
                break
            }
        }
        
        if streak >= 3 {
            return Insight(
                title: language.localized("insights.savingsStreak.title"),
                body: language.localized("insights.savingsStreak.body", Int64(streak)),
                severityRaw: InsightSeverity.low.rawValue,
                estimatedMonthlyImpact: 0,
                categoryID: nil
            )
        }
        return nil
    }

    private func absolute(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}
