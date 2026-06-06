import Foundation

struct ParsedRowDTO {
    let externalID: String?
    let bookingDate: Date
    let valueDate: Date?
    let description: String
    let amount: Decimal
    let currencyCode: String
    let accountName: String?
}
