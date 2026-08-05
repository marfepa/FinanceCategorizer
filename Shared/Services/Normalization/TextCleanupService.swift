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

extension String {
    var isGenericBankingNoise: Bool {
        let normalized = self.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        let stopWords: Set<String> = [
            "sepa", "bizum", "transferencia", "trf", "ord", "orden", "s", "compra", "recibo",
            "ingreso", "enviado", "recibido", "pago", "tarjeta", "varios", "traspaso", "concepto",
            "movimiento", "operacion", "ref", "referencia", "adeudo", "abono"
        ]
        let tokens = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return true }
        return tokens.allSatisfy { stopWords.contains($0) || $0.count < 3 || Int($0) != nil }
    }
}
