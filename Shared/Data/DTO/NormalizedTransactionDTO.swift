import Foundation

struct NormalizedTransactionDTO {
    let externalID: String?
    let bookingDate: Date
    let valueDate: Date?
    let rawDescription: String
    let cleanedDescription: String
    let merchantDisplayName: String?
    let merchantCanonicalName: String?
    let amount: Decimal
    let currencyCode: String
    let accountName: String?
    let sign: Int
    let fingerprint: String
}
