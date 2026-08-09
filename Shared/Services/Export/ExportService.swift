import Foundation

final class ExportService {
    enum PrivacyMode: String, Codable {
        case full
        case anonymized
    }

    enum ExportFormat {
        case csv
    }

    static func generateCSV(
        from transactions: [Transaction],
        categories: [Category],
        locale: Locale = .current,
        privacyMode: PrivacyMode = .full
    ) -> String {
        let isEuropeanLocale = locale.decimalSeparator == ","
        let delimiter = isEuropeanLocale ? ";" : ","
        
        var csv = "Date\(delimiter)Concept\(delimiter)Merchant\(delimiter)Amount\(delimiter)Type\(delimiter)Category\(delimiter)Confidence\(delimiter)Status\n"

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

        for (index, tx) in transactions.enumerated() {
            let escape: (String) -> String = { text in
                let cleaned = text.replacingOccurrences(of: "\"", with: "\"\"")
                if cleaned.contains(delimiter) || cleaned.contains("\"") || cleaned.contains("\n") {
                    return "\"\(cleaned)\""
                }
                return cleaned
            }

            let dateString = tx.bookingDate.formatted(date: .numeric, time: .omitted)
            let concept = privacyMode == .anonymized
                ? escape("Movement \(index + 1)")
                : escape(tx.rawDescription)
            let merchant = privacyMode == .anonymized
                ? ""
                : escape(tx.merchantCanonicalName ?? "")
            
            // Format amount based on locale
            let amountString = tx.amount.formatted(.number)
            let rawAmount = escape(amountString)
            
            let kind = tx.resolvedKind.rawValue.capitalized
            
            let categoryName = escape(tx.categoryID.flatMap { categoryMap[$0] } ?? "Sin categorizar")
            let confidence = escape(tx.confidence.formatted(.percent.precision(.fractionLength(0))))
            let status = escape(tx.reviewStatusRaw.capitalized)

            let row = [
                dateString,
                concept,
                merchant,
                rawAmount,
                kind,
                categoryName,
                confidence,
                status
            ].joined(separator: delimiter)

            csv.append(row + "\n")
        }

        return csv
    }
}
