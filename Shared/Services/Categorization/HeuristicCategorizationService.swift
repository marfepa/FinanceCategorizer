import Foundation

/// High-signal merchant terms used to keep supermarket purchases together.
/// Single-word brands are matched as complete words so a word such as "dia"
/// cannot match unrelated descriptions.
struct CategoryTextSignals {
    private static let supermarketTerms = [
        "mercadona", "consum", "carrefour", "aldi", "lidl", "dia",
        "ahorramas", "alcampo", "eroski", "hipercor", "supercor",
        "bonarea", "bonpreu", "caprabo", "condis", "coviran", "froiz",
        "gadis", "hiperber", "masymas", "mas y mas", "simply", "spar",
        "makro", "costco", "supermercado", "hipermercado"
    ]

    static func containsSupermarket(in text: String) -> Bool {
        let normalized = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let words = Set(normalized.split { $0 == " " || $0 == "-" || $0 == "_" }.map(String.init))

        return supermarketTerms.contains { term in
            term.contains(" ") ? normalized.contains(term) : words.contains(term)
        }
    }
}
@MainActor
protocol TransactionClassifying {
    func predict(_ input: NormalizedTransactionDTO) -> CategorizationDecision?
}

private struct CategoryHeuristicDefinition {
    let name: String
    let strongTerms: [String]
    let supportingTerms: [String]
}

private struct HeuristicPrediction {
    let categoryName: String
    let confidence: Double
    let matchedTerms: [String]
}

private struct CategoryHeuristicMatcher {
    private let definitions: [CategoryHeuristicDefinition] = [
        CategoryHeuristicDefinition(
            name: "Alimentacion",
            strongTerms: [
                "MERCADONA", "CONSUM", "CARREFOUR", "ALDI", "LIDL", "PRIMAPRIX",
                "FRUTERIA", "SUPERMERCADO", "MERCAT", "EL REBOST", "DULCES RAF",
                "AHORRAMAS", "ALCAMPO", "EROSKI", "DIA ", "MASYMAS"
            ],
            supportingTerms: ["ALIMENTACION", "COMESTIBLES", "TIENDA", "KUUPS", "MERKA"]
        ),
        CategoryHeuristicDefinition(
            name: "Restauracion",
            strongTerms: [
                "RESTAURANTE", "PIZZA", "BURGER", "BURGUER", "CHURRERIA", "HORNO",
                "TAVERNA", "CAFETERIA", "CAFE", "BAR ", "VENDING", "GOURMET",
                "GLOVO", "UBER EATS", "JUST EAT", "STARBUCKS", "MCDONALDS", "KFC"
            ],
            supportingTerms: ["COMIDA", "CENA", "DESAYUNO", "MENU", "ANEM DE PIZZA", "TAKEAWAY"]
        ),
        CategoryHeuristicDefinition(
            name: "Compras",
            strongTerms: [
                "AMAZON", "WALLAPOP", "SPRINGFIELD", "ZAPATERIA", "ZARA", "PEPCO",
                "MANGO", "YILISHA", "XTI FOOTWEAR", "TIENDAS", "COMPRAS", "MULTIPRECIO",
                "SHEIN", "TEMU", "ALIEXPRESS", "PRIMARK", "PULL BEAR", "BERSHKA", "HM "
            ],
            supportingTerms: ["TIENDA", "OUTLET", "MARKETPLACE", "ROPA"]
        ),
        CategoryHeuristicDefinition(
            name: "Transporte",
            strongTerms: [
                "CEPSA", "GASOLINERA", "RENFE", "IRYO", "METRO", "TAXI", "CABIFY",
                "TOYOTA", "TALLER", "REPARACION COCHE", "REPSOL ESTACION",
                "GALP", "SHELL", "BP ", "EMT", "BLABLACAR"
            ],
            supportingTerms: ["PARKING", "APARCAMIENTO", "PEAJE", "TRANSPORTE", "UBER"]
        ),
        CategoryHeuristicDefinition(
            name: "Hogar",
            strongTerms: [
                "IKEA", "LEROY MERLIN", "FERRETERIA", "INSTALACIONES", "REPARACION",
                "HOGAR PLUS", "MUEBLES", "ELECTRODOMESTICOS", "SEGURO HOGAR", "AUREUM", "TEIKA",
                "HIPOTECA", "ALQUILER", "AMORTIZACION HIPOTECA", "COMUNIDAD PROPIETARIOS"
            ],
            supportingTerms: ["CASA", "COMUNIDAD", "DECORACION", "VIVIENDA"]
        ),
        CategoryHeuristicDefinition(
            name: "Suministros",
            strongTerms: [
                "REPSOL COMERCIALIZADORA", "ELECTRICIDAD", "ENDESA", "IBERDROLA", "NATURGY",
                "AGUA", "AGUAS DE VALENCIA", "DIGI", "GAS NATURAL", "MOVISTAR", "VODAFONE", "ORANGE", "TELEFONIA",
                "JAZZTEL", "MASMOVIL", "YOIGO", "PEPEPHONE", "AQUALIA", "FACTURA LUZ"
            ],
            supportingTerms: ["LUZ", "GAS", "INTERNET", "SUMINISTRO", "FACTURA ELECTRICA", "FIBRA"]
        ),
        CategoryHeuristicDefinition(
            name: "Suscripciones",
            strongTerms: [
                "NETFLIX", "SPOTIFY", "APPLE BILL", "ITUNES", "ICLOUD", "YOUTUBE PREMIUM",
                "OPENAI", "CHATGPT", "AMAZON PRIME", "DISNEY PLUS", "HBO", "DAZN", "ICLOUD"
            ],
            supportingTerms: ["SUSCRIPCION", "SUBSCRIPTION", "PREMIUM", "CUOTA DIGITAL"]
        ),
        CategoryHeuristicDefinition(
            name: "Salud",
            strongTerms: [
                "HSN STORE", "FARMACIA", "HOSPITAL", "CLINICA", "DENTAL", "SEGURO SALUD",
                "MEDICO", "SANITAS", "NUTRIBEN", "ADESLAS", "ASISA"
            ],
            supportingTerms: ["SALUD", "MEDICAMENTO", "FISIOTERAPIA", "NUTRICION"]
        ),
        CategoryHeuristicDefinition(
            name: "Cuidado personal",
            strongTerms: ["BARBERIA", "PELUQUERIA", "DRUNI", "PERFUMERIA", "ESTETICA"],
            supportingTerms: ["BELLEZA", "COSMETICA"]
        ),
        CategoryHeuristicDefinition(
            name: "Deportes",
            strongTerms: ["DECATHLON", "GIMNASIO", "GYM", "COACH", "SPORT"],
            supportingTerms: ["DEPORTE", "FITNESS", "RUNNING"]
        ),
        CategoryHeuristicDefinition(
            name: "Ocio",
            strongTerms: ["CINESA", "YELMO", "CINE", "STEAM", "PLAYSTATION", "CONCIERTO", "ENTRADAS"],
            supportingTerms: ["OCIO", "ESPECTACULO", "VIDEOJUEGO"]
        ),
        CategoryHeuristicDefinition(
            name: "Educacion",
            strongTerms: ["UNIVERSIDAD", "COLEGIO", "ACADEMIA", "UDEMY", "COURSERA", "MATRICULA"],
            supportingTerms: ["EDUCACION", "FORMACION", "CURSO"]
        ),
        CategoryHeuristicDefinition(
            name: "Viajes",
            strongTerms: ["HOTEL", "AIRBNB", "CAMPING", "IRYO", "VIAJE", "GATE GOURMET", "BOOKING", "RYANAIR", "VUELING"],
            supportingTerms: ["ALOJAMIENTO", "RESERVA", "TURISMO"]
        ),
        CategoryHeuristicDefinition(
            name: "Inversión",
            strongTerms: [
                "INDEXA", "MYINVESTOR", "DEGIRO", "TRADE REPUBLIC", "BINANCE", "COINBASE",
                "OPENBANK INVERSION", "RENTA 4", "SELF BANK", "SCALABLE", "INVERSIS", "BROKER"
            ],
            supportingTerms: ["FONDOS", "FONDO", "INVERSION", "CARTERA"]
        ),
        CategoryHeuristicDefinition(
            name: "Efectivo",
            strongTerms: ["DISPOSICION EN CAJERO", "RETIRADA EFECTIVO", "RETIRADA CAJERO", "CAJERO"],
            supportingTerms: ["EFECTIVO"]
        ),
        CategoryHeuristicDefinition(
            name: "Donaciones",
            strongTerms: ["PARROQUIA", "DONACION", "ONG", "UNICEF", "CRUZ ROJA"],
            supportingTerms: ["SOLIDARIO", "APORTACION"]
        ),
        CategoryHeuristicDefinition(
            name: "Impuestos",
            strongTerms: ["AEAT", "HACIENDA", "IRPF", "IMPUESTOS", "TASA", "TRIBUTO"],
            supportingTerms: ["DECLARACION", "AUTOLIQUIDACION", "RECAUDACION"]
        ),
        CategoryHeuristicDefinition(
            name: "Finanzas",
            strongTerms: [
                "COMISION", "INTERESES", "AMORTIZACION", "PRESTAMO", "VISA",
                "MASTERCARD", "TARJETA DE CREDITO", "CAPITAL SOCIAL"
            ],
            supportingTerms: ["BANCO", "CREDITO", "FINANCIACION", "CUOTA"]
        ),
        CategoryHeuristicDefinition(
            name: "Ingresos",
            strongTerms: ["NOMINA", "SALARIO", "PENSION", "REMUNERACION", "RENTAS", "DEVOLUCION", "REEMBOLSO", "ABONO", "BONIFICACION", "BIZUM DE"],
            supportingTerms: ["INGRESO", "TRANSFERENCIA DE DEVOLUCIONES", "RETENCION HACIENDA"]
        ),
        CategoryHeuristicDefinition(
            name: "Transferencias",
            strongTerms: ["TRASPASO", "TRANSFERENCIA ENTRE CUENTAS", "ORDEN TRANSFERENCIA", "RECARGA TARJETA PREPAGO", "DESCARGA TARJETA PREPAGO", "ABONO EN LA TARJETA", "BIZUM A FAVOR"],
            supportingTerms: ["BIZUM", "TRANSFERENCIA", "FERNANDEZ PARDO MARIO"]
        )
    ]

    func predict(for input: NormalizedTransactionDTO) -> HeuristicPrediction? {
        let text = normalizedText(for: input)
        guard !text.isEmpty else { return nil }

        let scored = definitions.compactMap { definition -> (CategoryHeuristicDefinition, Double, [String])? in
            let strongMatches = definition.strongTerms.filter { containsTerm($0, in: text) }
            let supportingMatches = definition.supportingTerms.filter { containsTerm($0, in: text) }
            let score = Double(strongMatches.count) * 4.0 + Double(supportingMatches.count) * 1.6
            guard score > 0 else { return nil }
            return (definition, score, strongMatches + supportingMatches)
        }
        .sorted { $0.1 > $1.1 }

        guard let best = scored.first else { return nil }
        if best.0.name == "Ingresos", input.sign < 0 {
            return nil
        }

        if input.resolvedKind == .transfer, best.0.name != "Transferencias" {
            return nil
        }

        let runnerUp = scored.dropFirst().first?.1 ?? 0
        let margin = best.1 - runnerUp
        let baseConfidence: Double
        switch best.1 {
        case 4...: baseConfidence = 0.94
        case 2.5..<4: baseConfidence = 0.84
        default: baseConfidence = 0.68
        }

        let ambiguityPenalty = runnerUp > 0 && margin < 1.6 ? 0.14 : 0
        let positiveExpensePenalty = input.sign > 0 && best.0.name != "Ingresos" && best.0.name != "Transferencias" ? 0.10 : 0
        let confidence = min(0.96, max(0.55, baseConfidence - ambiguityPenalty - positiveExpensePenalty))

        return HeuristicPrediction(
            categoryName: best.0.name,
            confidence: confidence,
            matchedTerms: best.2
        )
    }

    private func normalizedText(for input: NormalizedTransactionDTO) -> String {
        [input.merchantCanonicalName, input.cleanedDescription, input.rawDescription]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsTerm(_ term: String, in text: String) -> Bool {
        let normalizedTerm = term
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTerm.isEmpty else { return false }
        return " \(text) ".contains(" \(normalizedTerm) ")
    }
}

@MainActor
final class StatisticalClassifier: TransactionClassifying {
    private let categoryRepository: CategoryRepository
    private let localModelManager: LocalModelManager
    private let heuristicMatcher = CategoryHeuristicMatcher()

    init(categoryRepository: CategoryRepository, localModelManager: LocalModelManager) {
        self.categoryRepository = categoryRepository
        self.localModelManager = localModelManager
    }

    func predict(_ input: NormalizedTransactionDTO) -> CategorizationDecision? {
        let text = "\(input.merchantCanonicalName ?? "") \(input.cleanedDescription)".lowercased()

        // A high-signal supermarket rule must win over a stale local model
        // that learned a generic "Compras" label for the merchant.
        if CategoryTextSignals.containsSupermarket(in: text),
           let category = try? categoryRepository.fetchOrCreateBaseCategory(named: "Alimentacion", isIncome: false) {
            return CategorizationDecision(
                categoryID: category.id,
                subcategoryID: nil,
                source: .localML,
                confidence: 0.90,
                shouldQueueForReview: false,
                isRecurringCandidate: false,
                reason: "Matched a known supermarket merchant signal."
            )
        }

        if let learnedPrediction = localModelManager.predict(input),
           let category = try? categoryRepository.fetch(categoryID: learnedPrediction.categoryID) {
            return CategorizationDecision(
                categoryID: category.id,
                subcategoryID: nil,
                source: .localML,
                confidence: learnedPrediction.confidence,
                shouldQueueForReview: learnedPrediction.confidence < AppConfig.softAutoCategorizationThreshold,
                isRecurringCandidate: learnedPrediction.isRecurringCandidate,
                reason: learnedPrediction.reason
            )
        }

        guard let prediction = heuristicMatcher.predict(for: input),
              let category = try? categoryRepository.fetchOrCreateBaseCategory(
                named: prediction.categoryName,
                isIncome: prediction.categoryName == "Ingresos"
              ) else {
            return nil
        }

        let recurringTerms = ["NETFLIX", "SPOTIFY", "ICLOUD", "APPLE BILL", "SEGURO", "HIPOTECA", "ALQUILER", "NOMINA"]
        let normalizedReason = prediction.matchedTerms.joined(separator: ", ")
        return CategorizationDecision(
            categoryID: category.id,
            subcategoryID: nil,
            source: .localML,
            confidence: prediction.confidence,
            shouldQueueForReview: prediction.confidence < AppConfig.softAutoCategorizationThreshold,
            isRecurringCandidate: recurringTerms.contains(where: { normalizedReason.contains($0) }),
            reason: "Detected specific merchant/concept signals: \(normalizedReason)."
        )
    }
}
