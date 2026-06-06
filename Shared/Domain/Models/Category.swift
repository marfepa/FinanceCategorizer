import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var parentID: UUID?
    var isIncome: Bool
    var sortOrder: Int
    var isSystem: Bool

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        parentID: UUID? = nil,
        isIncome: Bool = false,
        sortOrder: Int = 0,
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.parentID = parentID
        self.isIncome = isIncome
        self.sortOrder = sortOrder
        self.isSystem = isSystem
    }
}
