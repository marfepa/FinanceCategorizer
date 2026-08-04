import Foundation

struct MerchantCanonicalizer {
    private let aliases: [String: String] = [
        "AMZN": "Amazon",
        "AMAZON EU": "Amazon",
        "AMAZON MKTPLACE": "Amazon",
        "MERCADONA SA": "Mercadona",
        "MERCADONA VALENCIA": "Mercadona",
        "CONSUM COOP": "Consum",
        "UBER TRIP": "Uber",
        "UBER EATS": "Uber Eats",
        "NETFLIX": "Netflix",
        "SPOTIFY": "Spotify"
    ]

    func canonicalize(_ merchant: String?) -> (displayName: String?, canonicalName: String?) {
        guard let merchant, !merchant.isEmpty else { return (nil, nil) }
        let normalized = merchant.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = aliases[normalized] {
            return (exact, exact)
        }

        if normalized.contains("AMAZON") {
            return ("Amazon", "Amazon")
        }
        if normalized.contains("MERCADONA") {
            return ("Mercadona", "Mercadona")
        }
        if normalized.contains("UBER EATS") {
            return ("Uber Eats", "Uber Eats")
        }
        if normalized.contains("UBER") {
            return ("Uber", "Uber")
        }

        let display = normalized
            .split(separator: " ")
            .prefix(3)
            .map(String.init)
            .joined(separator: " ")
            .capitalized
        return (display, display)
    }
}

struct MerchantExtractionService {
    func extract(from cleanedDescription: String) -> String {
        var tokens = cleanedDescription.split(separator: " ").map(String.init)

        // Card-wallet prefixes are payment rails, not merchants. Removing
        // them lets "APPLE PAY EN LIDL" resolve to Lidl and keeps rules and
        // merchant memory aligned with the actual supermarket.
        let paymentPrefixes = [
            ["APPLE", "PAY"],
            ["GOOGLE", "PAY"],
            ["SAMSUNG", "PAY"],
            ["PAYPAL"],
            ["BIZUM"]
        ]
        if let prefix = paymentPrefixes.first(where: { tokens.starts(with: $0) }) {
            tokens.removeFirst(prefix.count)
            if tokens.first == "EN" || tokens.first == "DE" {
                tokens.removeFirst()
            }
        }

        return tokens
            .prefix(3)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
