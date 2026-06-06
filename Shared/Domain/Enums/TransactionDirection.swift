import Foundation

enum TransactionDirection: String, Codable, CaseIterable {
    case income
    case expense
    case transfer
}
