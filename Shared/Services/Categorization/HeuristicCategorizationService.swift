import Foundation

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
                "FRUTERIA", "SUPERMERCADO", "MERCAT", "EL REBOST", "DULCES RAF"
            ],
            supportingTerms: ["ALIMENTACION", "COMESTIBLES", "TIENDA", "KUUPS", "MERKA"]
        ),
        CategoryHeuristicDefinition(
            name: "Restauracion",
            strongTerms: [
                "RESTAURANTE", "PIZZA", "BURGER", "BURGUER", "CHURRERIA", "HORNO",
                "TAVERNA", "CAFETERIA", "CAFE", "BAR ", "VENDING", "GOURMET"
            ],
            supportingTerms: ["COMIDA", "CENA", "DESAYUNO", "MENU", "ANEM DE PIZZA"]
        ),
        CategoryHeuristicDefinition(
            name: "Compras",
            strongTerms: [
                "AMAZON", "WALLAPOP", "SPRINGFIELD", "ZAPATERIA", "ZARA", "PEPCO",
                "COMPRAS", "MULTIPRECIO"
            ],
            supportingTerms: ["TIENDA", "OUTLET", "MARKETPLACE"]
        ),
        CategoryHeuristicDefinition(
            name: "Transporte",
            strongTerms: [
                "CEPSA", "GASOLINERA", "RENFE", "IRYO", "METRO", "TAXI", "CABIFY",
                "TOYOTA", "TALLER", "REPARACION COCHE", "REPSOL ESTACION"
            ],
            supportingTerms: ["PARKING", "APARCAMIENTO", "PEAJE", "TRANSPORTE", "UBER"]
        ),
        CategoryHeuristicDefinition(
            name: "Hogar",
            strongTerms: [
                "IKEA", "LEROY MERLIN", "FERRETERIA", "INSTALACIONES", "REPARACION",
                "HOGAR PLUS", "MUEBLES", "ELECTRODOMESTICOS", "SEGURO HOGAR"
            ],
            supportingTerms: ["CASA", "COMUNIDAD", "ALQUILER", "DECORACION"]
        ),
        CategoryHeuristicDefinition(
            name: "Suministros",
            strongTerms: [
                "REPSOL COMERCIALIZADORA", "ELECTRICIDAD", "ENDESA", "IBERDROLA", "NATURGY",
                "AGUA", "GAS NATURAL", "MOVISTAR", "VODAFONE", "ORANGE", "TELEFONIA"
            ],
            supportingTerms: ["LUZ", "GAS", "INTERNET", "SUMINISTRO", "FACTURA ELECTRICA"]
        ),
        CategoryHeuristicDefinition(
            name: "Suscripciones",
            strongTerms: [
                "NETFLIX", "SPOTIFY", "APPLE BILL", "ITUNES", "ICLOUD", "YOUTUBE PREMIUM",
                "OPENAI", "CHATGPT", "AMAZON PRIME"
            ],
            supportingTerms: ["SUSCRIPCION", "SUBSCRIPTION", "PREMIUM", "CUOTA DIGITAL"]
        ),
        CategoryHeuristicDefinition(
            name: "Salud",
            strongTerms: [
                "HSN STORE", "FARMACIA", "HOSPITAL", "CLINICA", "DENTAL", "SEGURO SALUD",
                "MEDICO", "SANITAS"
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
            name: "Viajes",
            strongTerms: ["HOTEL", "AIRBNB", "CAMPING", "IRYO", "VIAJE", "GATE GOURMET"],
            supportingTerms: ["ALOJAMIENTO", "RESERVA", "TURISMO"]
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
                "COMISION", "INTERESES", "AMORTIZACION", "PRESTAMO", "HIPOTECA", "VISA",
                "MASTERCARD", "TARJETA DE CREDITO", "CAPITAL SOCIAL"
            ],
            supportingTerms: ["BANCO", "CREDITO", "FINANCIACION", "CUOTA"]
        ),
        CategoryHeuristicDefinition(
            name: "Ingresos",
            strongTerms: ["NOMINA", "SALARIO", "PENSION", "REMUNERACION", "RENTAS"],
            supportingTerms: ["INGRESO", "DEVOLUCION", "REEMBOLSO"]
        ),
        CategoryHeuristicDefinition(
            name: "Transferencias",
            strongTerms: ["TRASPASO", "TRANSFERENCIA ENTRE CUENTAS", "ORDEN TRANSFERENCIA"],
            supportingTerms: ["BIZUM", "TRANSFERENCIA", "MARIO FERNANDEZ PARDO"]
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
