import Foundation

struct ParsedRowDTO {
    let externalID: String?
    let bookingDate: Date
    let valueDate: Date?
    let description: String
    let amount: Decimal
    let balance: Decimal?
    let currencyCode: String
    let accountName: String?

    init(
        externalID: String?,
        bookingDate: Date,
        valueDate: Date?,
        description: String,
        amount: Decimal,
        balance: Decimal? = nil,
        currencyCode: String,
        accountName: String?
    ) {
        self.externalID = externalID
        self.bookingDate = bookingDate
        self.valueDate = valueDate
        self.description = description
        self.amount = amount
        self.balance = balance
        self.currencyCode = currencyCode
        self.accountName = accountName
    }
}
