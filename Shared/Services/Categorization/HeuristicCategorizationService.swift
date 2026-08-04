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

@MainActor
final class StatisticalClassifier: TransactionClassifying {
    private let categoryRepository: CategoryRepository
    private let localModelManager: LocalModelManager

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

        let categoryName: String?
        if CategoryTextSignals.containsSupermarket(in: text) {
            categoryName = "Alimentacion"
        } else if containsAny(text, ["netflix", "spotify", "icloud", "youtube premium", "openai", "chatgpt"]) {
            categoryName = "Suscripciones"
        } else if containsAny(text, ["uber eats", "glovo", "just eat", "restaurante", "burger", "pizza"]) {
            categoryName = "Restauracion"
        } else if containsAny(text, ["repsol", "cepsa", "uber", "cabify", "renfe", "metro"]) {
            categoryName = "Transporte"
        } else if containsAny(text, ["nomina", "nomina", "ingreso", "salario"]) || input.sign > 0 {
            categoryName = "Ingresos"
        } else {
            categoryName = nil
        }

        guard let categoryName,
              let category = try? categoryRepository.fetchOrCreateBaseCategory(named: categoryName, isIncome: categoryName == "Ingresos") else {
            return nil
        }

        return CategorizationDecision(
            categoryID: category.id,
            subcategoryID: nil,
            source: .localML,
            confidence: categoryName == "Ingresos" ? 0.84 : 0.78,
            shouldQueueForReview: true,
            isRecurringCandidate: containsAny(text, ["netflix", "spotify", "icloud", "seguro", "alquiler"]),
            reason: "Local statistical classifier matched known merchant and concept patterns."
        )
    }

    private func containsAny(_ text: String, _ values: [String]) -> Bool {
        let words = Set(text.split { $0 == " " || $0 == "-" || $0 == "_" }.map(String.init))
        return values.contains { value in
            value.contains(" ") ? text.contains(value) : words.contains(value)
        }
    }
}
