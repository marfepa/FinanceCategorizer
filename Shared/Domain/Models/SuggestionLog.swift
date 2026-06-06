import Foundation
import SwiftData

@Model
final class Insight {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var severityRaw: String
    var estimatedMonthlyImpact: Decimal?
    var categoryID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        severityRaw: String,
        estimatedMonthlyImpact: Decimal? = nil,
        categoryID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.severityRaw = severityRaw
        self.estimatedMonthlyImpact = estimatedMonthlyImpact
        self.categoryID = categoryID
        self.createdAt = createdAt
    }
}
