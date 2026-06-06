import Foundation
import SwiftData

@Model
final class Rule {
    @Attribute(.unique) var id: UUID
    var name: String
    var isEnabled: Bool
    var merchantContains: String?
    var descriptionContains: String?
    var amountMin: Decimal?
    var amountMax: Decimal?
    var amountSign: Int?
    var targetCategoryID: UUID
    var targetSubcategoryID: UUID?
    var priority: Int
    var createdFromUserCorrection: Bool
    var hitCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        merchantContains: String? = nil,
        descriptionContains: String? = nil,
        amountMin: Decimal? = nil,
        amountMax: Decimal? = nil,
        amountSign: Int? = nil,
        targetCategoryID: UUID,
        targetSubcategoryID: UUID? = nil,
        priority: Int = 100,
        createdFromUserCorrection: Bool = false,
        hitCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.merchantContains = merchantContains
        self.descriptionContains = descriptionContains
        self.amountMin = amountMin
        self.amountMax = amountMax
        self.amountSign = amountSign
        self.targetCategoryID = targetCategoryID
        self.targetSubcategoryID = targetSubcategoryID
        self.priority = priority
        self.createdFromUserCorrection = createdFromUserCorrection
        self.hitCount = hitCount
    }
}
