import Foundation

struct SavingsStrategyConfig: Codable, Equatable {
    var needsPercent: Int
    var wantsPercent: Int
    var investmentPercent: Int
    var tolerancePercentPoints: Int
    var includeResidualAsInvestment: Bool
    /// Persisted overrides keyed by category UUID string.
    var categoryBucketOverrides: [String: String]

    static let `default` = SavingsStrategyConfig(
        needsPercent: 50,
        wantsPercent: 30,
        investmentPercent: 20,
        tolerancePercentPoints: 2,
        includeResidualAsInvestment: true,
        categoryBucketOverrides: [:]
    )

    var preset: SavingsStrategyPreset {
        SavingsStrategyPreset.matching(
            needs: needsPercent,
            wants: wantsPercent,
            investment: investmentPercent
        )
    }

    var isBalanced: Bool {
        needsPercent + wantsPercent + investmentPercent == 100
            && needsPercent >= 0
            && wantsPercent >= 0
            && investmentPercent >= 0
    }

    func bucket(for category: Category) -> SavingsAllocationBucket? {
        if let raw = categoryBucketOverrides[category.id.uuidString] {
            if raw == Self.unassignedOverrideValue {
                return nil
            }
            return SavingsAllocationBucket(rawValue: raw)
        }
        return SavingsAllocationBucket.defaultBucket(forCategoryNamed: category.name, isIncome: category.isIncome)
    }

    func applying(preset: SavingsStrategyPreset) -> SavingsStrategyConfig {
        guard let ratios = preset.ratios else { return self }
        var copy = self
        copy.needsPercent = ratios.needs
        copy.wantsPercent = ratios.wants
        copy.investmentPercent = ratios.investment
        return copy
    }

    func assigning(_ categoryID: UUID, to bucket: SavingsAllocationBucket?) -> SavingsStrategyConfig {
        var copy = self
        copy.categoryBucketOverrides[categoryID.uuidString] = bucket?.rawValue ?? Self.unassignedOverrideValue
        return copy
    }

    private static let unassignedOverrideValue = "unassigned"

    func adjusting(bucket: SavingsAllocationBucket, delta: Int) -> SavingsStrategyConfig {
        var copy = self
        let current = copy.percent(for: bucket)
        let next = min(max(current + delta, 0), 100)
        let actualDelta = next - current
        guard actualDelta != 0 else { return self }

        copy.setPercent(next, for: bucket)

        let others = SavingsAllocationBucket.allCases.filter { $0 != bucket }
        var remaining = -actualDelta
        let ordered = others.sorted { copy.percent(for: $0) > copy.percent(for: $1) }

        for (index, other) in ordered.enumerated() {
            if index == ordered.count - 1 {
                copy.setPercent(min(max(copy.percent(for: other) + remaining, 0), 100), for: other)
                break
            }
            let available = copy.percent(for: other)
            if remaining < 0 {
                let take = min(available, -remaining)
                copy.setPercent(available - take, for: other)
                remaining += take
            } else {
                copy.setPercent(min(available + remaining, 100), for: other)
                remaining = 0
            }
        }

        let total = copy.needsPercent + copy.wantsPercent + copy.investmentPercent
        if total != 100 {
            copy.setPercent(copy.percent(for: bucket) + (100 - total), for: bucket)
            copy.setPercent(min(max(copy.percent(for: bucket), 0), 100), for: bucket)
        }
        return copy
    }

    func percent(for bucket: SavingsAllocationBucket) -> Int {
        switch bucket {
        case .needs: return needsPercent
        case .wants: return wantsPercent
        case .investment: return investmentPercent
        }
    }

    private mutating func setPercent(_ value: Int, for bucket: SavingsAllocationBucket) {
        switch bucket {
        case .needs: needsPercent = value
        case .wants: wantsPercent = value
        case .investment: investmentPercent = value
        }
    }
}

struct SavingsStrategyCategoryBreakdown: Identifiable, Equatable {
    let id: UUID
    let name: String
    let iconName: String
    let amount: Decimal
    let movementCount: Int
}

struct SavingsStrategyBucketResult: Identifiable, Equatable {
    let id: SavingsAllocationBucket
    let bucket: SavingsAllocationBucket
    let targetPercent: Int
    let actualAmount: Decimal
    let targetAmount: Decimal
    let actualPercent: Double
    let status: SavingsStrategyRangeStatus
    let categories: [SavingsStrategyCategoryBreakdown]
    let residualAmount: Decimal
    let explicitAmount: Decimal
    let movementCount: Int

    var deltaAmount: Decimal {
        actualAmount - targetAmount
    }

    var deltaPercentPoints: Double {
        actualPercent - Double(targetPercent)
    }
}

struct SavingsStrategySnapshot: Equatable {
    let monthStart: Date
    let income: Decimal
    let buckets: [SavingsStrategyBucketResult]
    let unassignedAmount: Decimal
    let unassignedCategories: [SavingsStrategyCategoryBreakdown]
    let unassignedMovementCount: Int
    let overallStatus: SavingsStrategyRangeStatus
    let isOnTrack: Bool
    let hasIncome: Bool

    func result(for bucket: SavingsAllocationBucket) -> SavingsStrategyBucketResult? {
        buckets.first { $0.bucket == bucket }
    }
}
