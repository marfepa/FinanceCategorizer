import Foundation

enum SavingsAllocationBucket: String, Codable, CaseIterable, Identifiable {
    case needs
    case wants
    case investment

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .needs: return "strategy.bucket.needs"
        case .wants: return "strategy.bucket.wants"
        case .investment: return "strategy.bucket.investment"
        }
    }

    var subtitleKey: String {
        switch self {
        case .needs: return "strategy.bucket.needs.subtitle"
        case .wants: return "strategy.bucket.wants.subtitle"
        case .investment: return "strategy.bucket.investment.subtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .needs: return "house.fill"
        case .wants: return "sparkles"
        case .investment: return "chart.line.uptrend.xyaxis"
        }
    }

    /// Spending over the target is a problem for needs and wants.
    /// Falling short of the target is a problem for investment.
    var treatsOverTargetAsFailure: Bool {
        self != .investment
    }

    static func defaultBucket(forCategoryNamed name: String, isIncome: Bool) -> SavingsAllocationBucket? {
        guard !isIncome else { return nil }

        let normalized = normalize(name)
        if excludedCategoryNames.contains(normalized) {
            return nil
        }
        if needsCategoryNames.contains(normalized) {
            return .needs
        }
        if wantsCategoryNames.contains(normalized) {
            return .wants
        }
        if investmentCategoryNames.contains(normalized) || looksLikeInvestment(normalized) {
            return .investment
        }
        return nil
    }

    /// Fallback when a movement has no mapped category: read merchant and description.
    static func inferred(from rawText: String) -> SavingsAllocationBucket? {
        let normalized = normalize(rawText)
        guard !normalized.isEmpty else { return nil }
        if excludedInferenceTokens.contains(where: { normalized.contains($0) }) {
            return nil
        }
        if investmentInferenceTokens.contains(where: { normalized.contains($0) }) {
            return .investment
        }
        if needsInferenceTokens.contains(where: { normalized.contains($0) }) {
            return .needs
        }
        if wantsInferenceTokens.contains(where: { normalized.contains($0) }) {
            return .wants
        }
        return nil
    }

    private static func normalize(_ name: String) -> String {
        name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looksLikeInvestment(_ normalized: String) -> Bool {
        let tokens = ["inversion", "investment", "ahorro", "broker", "fondos", "fondo"]
        return tokens.contains { normalized.contains($0) }
    }

    private static let needsCategoryNames: Set<String> = [
        "hogar",
        "vivienda",
        "alquiler",
        "hipoteca",
        "suministros",
        "transporte",
        "salud",
        "educacion",
        "impuestos",
        "alimentacion",
        "suscripciones",
        "internet",
        "seguros",
        "finanzas"
    ]

    private static let wantsCategoryNames: Set<String> = [
        "restauracion",
        "compras",
        "cuidado personal",
        "deportes",
        "ocio",
        "viajes",
        "donaciones",
        "efectivo"
    ]

    private static let investmentCategoryNames: Set<String> = [
        "inversion",
        "inversiones",
        "investment",
        "ahorro"
    ]

    private static let excludedCategoryNames: Set<String> = [
        "transferencias",
        "sin categorizar",
        "ingresos",
        "movimiento interno",
        "internal movement"
    ]

    private static let needsInferenceTokens = [
        "hipoteca", "alquiler", "comunidad", "ibi", "suministro", "endesa", "iberdrola",
        "naturgy", "movistar", "vodafone", "orange", "digi", "pepephone", "masmovil",
        "internet", "electricidad", "gas natural", "aguas", "mercadona", "lidl", "aldi",
        "carrefour", "consum", "seguro", "sanitas", "farmacia", "renfe", "gasolinera",
        "repsol", "cepsa", "nominas ss", "autonomo"
    ]

    private static let wantsInferenceTokens = [
        "amazon", "zara", "mango", "shein", "temu", "aliexpress", "primark",
        "restaurante", "burger", "pizza", "glovo", "uber eats", "starbucks",
        "cine", "steam", "playstation", "decathlon"
    ]

    private static let investmentInferenceTokens = [
        "indexa", "myinvestor", "degiro", "trade republic", "binance", "coinbase",
        "broker", "fondos", "fondo indexado", "inversores", "openbank inversion",
        "renta 4", "self bank", "scalable"
    ]

    private static let excludedInferenceTokens = [
        "traspaso", "cuenta propia", "transferencia interna"
    ]
}

enum SavingsStrategyPreset: String, Codable, CaseIterable, Identifiable {
    case fiftyThirtyTwenty
    case sixtyTwentyTwenty
    case seventyTwentyTen
    case custom

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .fiftyThirtyTwenty: return "strategy.preset.50-30-20"
        case .sixtyTwentyTwenty: return "strategy.preset.60-20-20"
        case .seventyTwentyTen: return "strategy.preset.70-20-10"
        case .custom: return "strategy.preset.custom"
        }
    }

    var ratios: (needs: Int, wants: Int, investment: Int)? {
        switch self {
        case .fiftyThirtyTwenty: return (50, 30, 20)
        case .sixtyTwentyTwenty: return (60, 20, 20)
        case .seventyTwentyTen: return (70, 20, 10)
        case .custom: return nil
        }
    }

    static func matching(needs: Int, wants: Int, investment: Int) -> SavingsStrategyPreset {
        for preset in SavingsStrategyPreset.allCases {
            if let ratios = preset.ratios,
               ratios.needs == needs,
               ratios.wants == wants,
               ratios.investment == investment {
                return preset
            }
        }
        return .custom
    }
}

enum SavingsStrategyRangeStatus: String, Equatable {
    case within
    case over
    case under

    var isOnTrack: Bool {
        self == .within
    }
}
