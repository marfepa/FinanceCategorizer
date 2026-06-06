import Foundation

struct Money: Codable, Equatable {
    let amount: Decimal
    let currencyCode: String
}
