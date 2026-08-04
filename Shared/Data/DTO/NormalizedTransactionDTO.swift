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
    let kind: TransactionKind?

    init(
        externalID: String?,
        bookingDate: Date,
        valueDate: Date?,
        rawDescription: String,
        cleanedDescription: String,
        merchantDisplayName: String?,
        merchantCanonicalName: String?,
        amount: Decimal,
        currencyCode: String,
        accountName: String?,
        sign: Int,
        fingerprint: String,
        kind: TransactionKind? = nil
    ) {
        self.externalID = externalID
        self.bookingDate = bookingDate
        self.valueDate = valueDate
        self.rawDescription = rawDescription
        self.cleanedDescription = cleanedDescription
        self.merchantDisplayName = merchantDisplayName
        self.merchantCanonicalName = merchantCanonicalName
        self.amount = amount
        self.currencyCode = currencyCode
        self.accountName = accountName
        self.sign = sign
        self.fingerprint = fingerprint
        self.kind = kind
    }

    var resolvedKind: TransactionKind {
        kind ?? (sign >= 0 ? .income : .expense)
    }
}
