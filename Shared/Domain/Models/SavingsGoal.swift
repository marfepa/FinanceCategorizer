import Foundation
import SwiftData

enum SavingsGoalKind: String, CaseIterable, Identifiable {
    case emergency
    case investment
    case travel
    case home
    case other

    var id: String { rawValue }
}

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var targetAmount: Decimal
    var allocatedAmount: Decimal
    var monthlyContribution: Decimal
    var targetDate: Date?
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        kind: SavingsGoalKind = .other,
        targetAmount: Decimal,
        allocatedAmount: Decimal = .zero,
        monthlyContribution: Decimal = .zero,
        targetDate: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.targetAmount = targetAmount
        self.allocatedAmount = allocatedAmount
        self.monthlyContribution = monthlyContribution
        self.targetDate = targetDate
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

extension SavingsGoal {
    var kind: SavingsGoalKind {
        get { SavingsGoalKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var remainingAmount: Decimal {
        max(targetAmount - allocatedAmount, .zero)
    }
}
