import Foundation

struct FingerprintBuilder {
    func build(bookingDate: Date, cleanedDescription: String, amount: Decimal, currencyCode: String) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            formatter.string(from: Calendar.current.startOfDay(for: bookingDate)),
            cleanedDescription.lowercased(),
            NSDecimalNumber(decimal: amount).stringValue,
            currencyCode
        ].joined(separator: "|")
    }
}
