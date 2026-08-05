import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var institution: String?
    var currencyCode: String
    /// Last confirmed balance. Optional when the imported statement has no
    /// balance column and the user has not confirmed it manually yet.
    var currentBalance: Decimal?
    var balanceAsOf: Date?
    var balanceSourceRaw: String?
    var isLiability: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        institution: String? = nil,
        currencyCode: String = AppConfig.defaultCurrencyCode,
        currentBalance: Decimal? = nil,
        balanceAsOf: Date? = nil,
        balanceSourceRaw: String? = nil,
        isLiability: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.institution = institution
        self.currencyCode = currencyCode
        self.currentBalance = currentBalance
        self.balanceAsOf = balanceAsOf
        self.balanceSourceRaw = balanceSourceRaw
        self.isLiability = isLiability
        self.createdAt = createdAt
    }
}
