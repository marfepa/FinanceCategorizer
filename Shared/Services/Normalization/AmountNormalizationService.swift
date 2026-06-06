import Foundation

struct AmountSignResolver {
    func resolveSign(amount: Decimal, rawDescription: String) -> Int {
        if amount > 0 { return 1 }
        if amount < 0 { return -1 }
        let lowered = rawDescription.lowercased()
        if lowered.contains("nomina") || lowered.contains("ingreso") || lowered.contains("bizum recibido") {
            return 1
        }
        return -1
    }
}
