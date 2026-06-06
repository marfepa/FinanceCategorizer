import Foundation

enum TransactionKind: String, Codable, CaseIterable {
    case expense
    case income
    case transfer
    case adjustment
}
