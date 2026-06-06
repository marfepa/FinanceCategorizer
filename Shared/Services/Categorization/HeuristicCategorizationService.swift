import Foundation

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

        let text = "\(input.merchantCanonicalName ?? "") \(input.cleanedDescription)".lowercased()

        let categoryName: String?
        if containsAny(text, ["mercadona", "consum", "carrefour", "aldi", "lidl", "dia", "super"]) {
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
        values.contains(where: { text.contains($0) })
    }
}
