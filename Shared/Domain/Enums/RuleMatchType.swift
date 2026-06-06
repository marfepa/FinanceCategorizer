import Foundation

enum RuleMatchType: String, Codable, CaseIterable {
    case merchantContains
    case conceptContains
    case amountEquals
}
