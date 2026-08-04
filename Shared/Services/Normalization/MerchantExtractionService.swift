import Foundation

struct MerchantCanonicalizer {
    private let aliases: [String: String] = [
        "AMZN": "Amazon",
        "AMAZON EU": "Amazon",
        "AMAZON MKTPLACE": "Amazon",
        "MERCADONA SA": "Mercadona",
        "MERCADONA VALENCIA": "Mercadona",
        "CONSUM COOP": "Consum",
        "CONSUM": "Consum",
        "CARREFOUR": "Carrefour",
        "CARREF": "Carrefour",
        "ALDI": "Aldi",
        "LIDL": "Lidl",
        "APPLE BILL ITUNES": "Apple iTunes",
        "ITUNES.COM": "Apple iTunes",
        "HSN STORE.COM": "HSN Store",
        "DECATHLON": "Decathlon",
        "IKEA VALENCIA HFB": "IKEA",
        "LEROY MERLIN": "Leroy Merlin",
        "DRUNI": "Druni",
        "BARBERIA": "Barberia",
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
        if normalized.contains("CARREFOUR") || normalized.hasPrefix("CARREF") {
            return ("Carrefour", "Carrefour")
        }
        if normalized.contains("CONSUM") {
            return ("Consum", "Consum")
        }
        if normalized.contains("APPLE") && normalized.contains("ITUNES") {
            return ("Apple iTunes", "Apple iTunes")
        }
        if normalized.contains("HSN STORE") {
            return ("HSN Store", "HSN Store")
        }
        if normalized.contains("DECATHLON") {
            return ("Decathlon", "Decathlon")
        }
        if normalized.contains("IKEA") {
            return ("IKEA", "IKEA")
        }
        if normalized.contains("LEROY MERLIN") {
            return ("Leroy Merlin", "Leroy Merlin")
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
