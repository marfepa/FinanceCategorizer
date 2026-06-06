import Foundation

struct AIPromptBuilder {
    func buildPrompt(
        for transaction: Transaction,
        merchantName: String,
        candidateCategories: [String],
        fallbackCategories: [Category]
    ) -> String {
        let narrowedCategories = candidateCategories.isEmpty ? fallbackCategories.map(\.name) : candidateCategories
        let availableCategories = narrowedCategories.joined(separator: ", ")
        let direction = transaction.amount.sign == .minus ? "expense" : "income"
        return """
        Categorize this bank transaction into exactly one of these categories: \(availableCategories).
        Concept: \(transaction.rawDescription)
        Normalized concept: \(transaction.cleanedDescription)
        Merchant candidate: \(merchantName)
        Direction: \(direction)
        Amount: \(transaction.amount)
        Currency: \(transaction.currencyCode)
        Return the best category, a confidence from 0 to 1, and a short explanation.
        """
    }
}
