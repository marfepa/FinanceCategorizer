import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var institution: String?
    var currencyCode: String

    init(id: UUID = UUID(), name: String, institution: String? = nil, currencyCode: String = AppConfig.defaultCurrencyCode) {
        self.id = id
        self.name = name
        self.institution = institution
        self.currencyCode = currencyCode
    }
}
