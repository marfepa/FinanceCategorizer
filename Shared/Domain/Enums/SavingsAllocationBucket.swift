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
        "seguros"
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
