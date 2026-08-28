import Foundation

/// Resolves the financial meaning of a movement from its stored kind, amount and
/// bank description. The import path uses this before categorization so that
/// internal card/account movements never inflate income or spending totals.
struct TransactionKindResolver {
    func resolve(
        storedKindRaw: String? = nil,
        rawDescription: String,
        cleanedDescription: String,
        amount: Decimal
    ) -> TransactionKind {
        let storedKind = storedKindRaw.flatMap(TransactionKind.init(rawValue:))
        if storedKind == .transfer || containsInternalTransferSignal(in: rawDescription + " " + cleanedDescription) {
            return .transfer
        }

        if let storedKind, storedKind == .adjustment {
            return .adjustment
        }

        if let storedKind, storedKind == .income, amount > .zero {
            return .income
        }

        if let storedKind, storedKind == .expense, amount < .zero {
            return .expense
        }

        return amount >= .zero ? .income : .expense
    }

    func containsInternalTransferSignal(in text: String) -> Bool {
        let normalized = normalize(text)
        let signals = [
            "TRASPASO ENTRE CUENTAS",
            "TRANSFERENCIA ENTRE CUENTAS",
            "TRANSFERENCIA PROPIA",
            "CUENTA PROPIA",
            "RECARGA TARJETA PREPAGO",
            "DESCARGA TARJETA PREPAGO",
            "ABONO EN LA TARJETA",
            "TRANSFERENCIA MISMO TITULAR",
            "TRASPASO MISMO TITULAR",
            "TRANSFERENCIA DE FERNANDEZ PARDO MARIO",
            "TRANSFERENCIA DE MARIO FERNANDEZ PARDO",
            "TRANSFERENCIA DE FERNANDEZ MARIO"
        ]

        return signals.contains { normalized.contains($0) }
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
