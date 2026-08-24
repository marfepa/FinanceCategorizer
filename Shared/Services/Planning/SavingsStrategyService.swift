import Foundation

struct SavingsStrategyService {
    private let classifier = FinancialMovementClassifier()

    func buildSnapshot(
        transactions: [Transaction],
        categories: [Category],
        config: SavingsStrategyConfig,
        monthStart: Date? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> SavingsStrategySnapshot? {
        let categoryByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let scope = FinancialReportingScope(now: now, dateBasis: .budget, calendar: calendar)
        let entries = scope.eligibleEntries(
            from: transactions,
            classifier: classifier,
            categoryMap: categoryMap
        )

        let resolvedMonthStart = monthStart
            ?? scope.activeMonthStart(from: transactions, classifier: classifier, categoryMap: categoryMap)
            ?? scope.startOfMonth(for: now)
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: resolvedMonthStart) else {
            return nil
        }

        let monthEntries = entries.filter { $0.date >= resolvedMonthStart && $0.date < monthEnd }
        let income = monthEntries
            .filter { classifier.isIncome($0.transaction) }
            .reduce(Decimal.zero) { $0 + $1.amount }

        var amounts: [SavingsAllocationBucket: Decimal] = [
            .needs: .zero,
            .wants: .zero,
            .investment: .zero
        ]
        var counts: [SavingsAllocationBucket: Int] = [
            .needs: 0,
            .wants: 0,
            .investment: 0
        ]
        var categoryAmounts: [SavingsAllocationBucket: [UUID: (name: String, icon: String, amount: Decimal, count: Int)]] = [
            .needs: [:],
            .wants: [:],
            .investment: [:]
        ]
        var unassignedAmount: Decimal = .zero
        var unassignedCount = 0
        var unassignedByCategory: [UUID: (name: String, icon: String, amount: Decimal, count: Int)] = [:]

        for entry in monthEntries where classifier.isExpense(entry.transaction) {
            let amount = abs(entry.amount)
            let category = resolvedCategory(for: entry.transaction, categoryByID: categoryByID)
            let bucket = category.flatMap { config.bucket(for: $0) }

            if let bucket, let category {
                amounts[bucket, default: .zero] += amount
                counts[bucket, default: 0] += 1
                var bucketCategories = categoryAmounts[bucket] ?? [:]
                var current = bucketCategories[category.id] ?? (category.name, category.iconName, .zero, 0)
                current.amount += amount
                current.count += 1
                bucketCategories[category.id] = current
                categoryAmounts[bucket] = bucketCategories
            } else {
                unassignedAmount += amount
                unassignedCount += 1
                let key = category?.id ?? SavingsStrategyService.uncategorizedID
                let name = category?.name ?? "Sin categorizar"
                let icon = category?.iconName ?? "questionmark.circle"
                var current = unassignedByCategory[key] ?? (name, icon, .zero, 0)
                current.amount += amount
                current.count += 1
                unassignedByCategory[key] = current
            }
        }

        let explicitInvestment = amounts[.investment] ?? .zero
        let needsAmount = amounts[.needs] ?? .zero
        let wantsAmount = amounts[.wants] ?? .zero
        let residual: Decimal
        if config.includeResidualAsInvestment, income > .zero {
            let leftover = income - needsAmount - wantsAmount - explicitInvestment - unassignedAmount
            residual = leftover > .zero ? leftover : .zero
        } else {
            residual = .zero
        }
        amounts[.investment] = explicitInvestment + residual

        let buckets = SavingsAllocationBucket.allCases.map { bucket in
            let actualAmount = amounts[bucket] ?? .zero
            let targetPercent = config.percent(for: bucket)
            let targetAmount = percentAmount(income, percent: targetPercent)
            let actualPercent = percentOfIncome(actualAmount, income: income)
            let status = rangeStatus(
                bucket: bucket,
                actualPercent: actualPercent,
                targetPercent: targetPercent,
                tolerance: config.tolerancePercentPoints,
                hasIncome: income > .zero
            )
            let breakdown = (categoryAmounts[bucket] ?? [:])
                .map { id, value in
                    SavingsStrategyCategoryBreakdown(
                        id: id,
                        name: value.name,
                        iconName: value.icon,
                        amount: value.amount,
                        movementCount: value.count
                    )
                }
                .sorted { $0.amount > $1.amount }

            return SavingsStrategyBucketResult(
                id: bucket,
                bucket: bucket,
                targetPercent: targetPercent,
                actualAmount: actualAmount,
                targetAmount: targetAmount,
                actualPercent: actualPercent,
                status: status,
                categories: breakdown,
                residualAmount: bucket == .investment ? residual : .zero,
                explicitAmount: bucket == .investment ? explicitInvestment : actualAmount,
                movementCount: counts[bucket] ?? 0
            )
        }

        let unassignedCategories = unassignedByCategory
            .map { id, value in
                SavingsStrategyCategoryBreakdown(
                    id: id,
                    name: value.name,
                    iconName: value.icon,
                    amount: value.amount,
                    movementCount: value.count
                )
            }
            .sorted { $0.amount > $1.amount }

        let isOnTrack = income > .zero && buckets.allSatisfy { $0.status.isOnTrack }
        let overall: SavingsStrategyRangeStatus
        if income <= .zero {
            overall = .under
        } else if isOnTrack {
            overall = .within
        } else if buckets.contains(where: { $0.bucket != .investment && $0.status == .over }) {
            overall = .over
        } else {
            overall = .under
        }

        return SavingsStrategySnapshot(
            monthStart: resolvedMonthStart,
            income: income,
            buckets: buckets,
            unassignedAmount: unassignedAmount,
            unassignedCategories: unassignedCategories,
            unassignedMovementCount: unassignedCount,
            overallStatus: overall,
            isOnTrack: isOnTrack,
            hasIncome: income > .zero
        )
    }

    func availableMonthStarts(
        transactions: [Transaction],
        categories: [Category],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let scope = FinancialReportingScope(now: now, dateBasis: .budget, calendar: calendar)
        let entries = scope.eligibleEntries(
            from: transactions,
            classifier: classifier,
            categoryMap: categoryMap
        )
        let months = Set(entries.map { scope.startOfMonth(for: $0.date) })
        return months.sorted(by: >)
    }

    private func resolvedCategory(
        for transaction: Transaction,
        categoryByID: [UUID: Category]
    ) -> Category? {
        if let categoryID = transaction.categoryID, let category = categoryByID[categoryID] {
            return category
        }
        if let subcategoryID = transaction.subcategoryID, let category = categoryByID[subcategoryID] {
            return category
        }
        return nil
    }

    private func percentAmount(_ income: Decimal, percent: Int) -> Decimal {
        guard income > .zero else { return .zero }
        return income * Decimal(percent) / Decimal(100)
    }

    private func percentOfIncome(_ amount: Decimal, income: Decimal) -> Double {
        guard income > .zero else { return 0 }
        return NSDecimalNumber(decimal: amount / income).doubleValue * 100
    }

    private func rangeStatus(
        bucket: SavingsAllocationBucket,
        actualPercent: Double,
        targetPercent: Int,
        tolerance: Int,
        hasIncome: Bool
    ) -> SavingsStrategyRangeStatus {
        guard hasIncome else { return .under }
        let target = Double(targetPercent)
        let slack = Double(max(tolerance, 0))
        if bucket.treatsOverTargetAsFailure {
            return actualPercent > target + slack ? .over : .within
        }
        return actualPercent < target - slack ? .under : .within
    }

    private static let uncategorizedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}
