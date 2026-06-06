import SwiftData
import Foundation

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var categoryID: UUID
    var monthYear: String // Format: "YYYY-MM"
    var limitAmount: Decimal
    var alertThreshold: Double // E.g., 0.8 for 80%

    init(
        id: UUID = UUID(),
        categoryID: UUID,
        monthYear: String,
        limitAmount: Decimal,
        alertThreshold: Double = 0.8
    ) {
        self.id = id
        self.categoryID = categoryID
        self.monthYear = monthYear
        self.limitAmount = limitAmount
        self.alertThreshold = alertThreshold
    }
}
