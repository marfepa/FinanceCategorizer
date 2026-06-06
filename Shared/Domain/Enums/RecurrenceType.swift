import Foundation

enum RecurrenceType: String, Codable, CaseIterable {
    case none
    case weekly
    case monthly
    case quarterly
    case yearly
}
