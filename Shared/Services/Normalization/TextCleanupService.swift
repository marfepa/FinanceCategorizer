import Foundation

struct DescriptionCleaner {
    private let noiseTokens = [
        "COMPRA TARJ", "PAGO CON TARJETA", "POS", "SEPA", "COMPRA", "TARJETA",
        "TRJ", "VISA", "MASTERCARD", "AUT.", "REF.", "OPERACION", "OP ", "CARD"
    ]

    func clean(_ text: String) -> String {
        var normalized = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "\\b\\d{4,}\\b", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[^A-Z0-9* ]", with: " ", options: .regularExpression)

        for token in noiseTokens {
            normalized = normalized.replacingOccurrences(of: token, with: " ")
        }

        return normalized
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
