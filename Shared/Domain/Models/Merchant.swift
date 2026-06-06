import Foundation
import SwiftData

@Model
final class Merchant {
    @Attribute(.unique) var id: UUID
    var normalizedName: String
    var displayName: String
    var canonicalName: String
    var usageCount: Int
    var preferredCategoryID: UUID?
    var averageConfidence: Double
    var lastSeenAt: Date?

    init(
        id: UUID = UUID(),
        normalizedName: String,
        displayName: String,
        canonicalName: String,
        usageCount: Int = 0,
        preferredCategoryID: UUID? = nil,
        averageConfidence: Double = 0,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.normalizedName = normalizedName
        self.displayName = displayName
        self.canonicalName = canonicalName
        self.usageCount = usageCount
        self.preferredCategoryID = preferredCategoryID
        self.averageConfidence = averageConfidence
        self.lastSeenAt = lastSeenAt
    }
}
