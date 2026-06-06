import Foundation
import SwiftData

@Model
final class ImportProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var bankIdentifier: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, bankIdentifier: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.bankIdentifier = bankIdentifier
        self.createdAt = createdAt
    }
}
