import Foundation
import SwiftData

@Model
final class UserCorrection {
    @Attribute(.unique) var id: UUID
    var transactionID: UUID
    var previousCategoryID: UUID?
    var newCategoryID: UUID
    var previousSubcategoryID: UUID?
    var newSubcategoryID: UUID?
    var previousConfidence: Double
    var originalSourceRaw: String
    var correctedAt: Date

    init(
        id: UUID = UUID(),
        transactionID: UUID,
        previousCategoryID: UUID?,
        newCategoryID: UUID,
        previousSubcategoryID: UUID? = nil,
        newSubcategoryID: UUID? = nil,
        previousConfidence: Double,
        originalSourceRaw: String,
        correctedAt: Date = .now
    ) {
        self.id = id
        self.transactionID = transactionID
        self.previousCategoryID = previousCategoryID
        self.newCategoryID = newCategoryID
        self.previousSubcategoryID = previousSubcategoryID
        self.newSubcategoryID = newSubcategoryID
        self.previousConfidence = previousConfidence
        self.originalSourceRaw = originalSourceRaw
        self.correctedAt = correctedAt
    }
}
