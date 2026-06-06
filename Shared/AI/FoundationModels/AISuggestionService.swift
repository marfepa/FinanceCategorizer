import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class FoundationModelsResolver {
    private let categoryRepository: CategoryRepository
    private let transactionRepository: TransactionRepository

    init(categoryRepository: CategoryRepository, transactionRepository: TransactionRepository) {
        self.categoryRepository = categoryRepository
        self.transactionRepository = transactionRepository
    }

    func resolve(_ tx: NormalizedTransactionDTO) async -> CategorizationDecision {
        #if canImport(FoundationModels)
        guard FoundationModelsAvailability.isUsable() else {
            return unavailableDecision()
        }

        if #available(macOS 26.0, iOS 26.0, *) {
            let categories = (try? categoryRepository.fetchAll()) ?? []
            let categoryNames = categories.map(\.name).joined(separator: ", ")
            let similarTransactions = (try? transactionRepository.findSimilarTransactions(description: tx.cleanedDescription, amount: tx.amount, limit: 5)) ?? []
            let context = similarTransactions
                .map { "\($0.cleanedDescription) => \($0.categoryID?.uuidString ?? "none")" }
                .joined(separator: "\n")

            let session = LanguageModelSession(
                instructions: """
                You classify personal finance transactions into a fixed category taxonomy.
                Be conservative and only choose a category when evidence is strong.
                """
            )

            let prompt = """
            Reply with exactly these lines:
            CATEGORY: <allowed category name or Unknown>
            CONFIDENCE: <number from 0 to 1>
            RECURRING: <true or false>
            REASON: <short explanation>

            Allowed categories: \(categoryNames)
            Transaction description: \(tx.cleanedDescription)
            Merchant: \(tx.merchantCanonicalName ?? "Unknown")
            Amount: \(tx.amount)
            Currency: \(tx.currencyCode)
            Similar transactions:
            \(context)
            """

            do {
                let response = try await session.respond(to: prompt)
                let parsed = parseStructuredDecision(String(describing: response.content))
                let matchedCategory = categories.first {
                    $0.name.caseInsensitiveCompare(parsed.categoryName) == .orderedSame
                }

                return CategorizationDecision(
                    categoryID: matchedCategory?.id,
                    subcategoryID: nil,
                    source: .foundationModel,
                    confidence: parsed.confidence,
                    shouldQueueForReview: parsed.confidence < 0.75 || matchedCategory == nil,
                    isRecurringCandidate: parsed.isRecurring,
                    reason: parsed.reason
                )
            } catch {
                return unavailableDecision()
            }
        }
        #endif

        return unavailableDecision()
    }

    private func unavailableDecision() -> CategorizationDecision {
        CategorizationDecision(
            categoryID: nil,
            subcategoryID: nil,
            source: .unknown,
            confidence: 0,
            shouldQueueForReview: true,
            isRecurringCandidate: false,
            reason: "Foundation model unavailable."
        )
    }

    private func parseStructuredDecision(_ text: String) -> AICategorizationDecision {
        let lines = text.components(separatedBy: .newlines)
        let category = lines.first(where: { $0.uppercased().hasPrefix("CATEGORY:") })?
            .split(separator: ":", maxSplits: 1).last.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
        let confidenceText = lines.first(where: { $0.uppercased().hasPrefix("CONFIDENCE:") })?
            .split(separator: ":", maxSplits: 1).last.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let confidence = confidenceText.flatMap { Double($0) } ?? 0.0
        let recurring = lines.first(where: { $0.uppercased().hasPrefix("RECURRING:") })?
            .split(separator: ":", maxSplits: 1).last.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "true"
        let reason = lines.first(where: { $0.uppercased().hasPrefix("REASON:") })?
            .split(separator: ":", maxSplits: 1).last.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Foundation model suggestion."

        return AICategorizationDecision(
            merchant: "",
            categoryName: category,
            subcategoryName: nil,
            confidence: confidence,
            isRecurring: recurring,
            shouldSuggestRule: false,
            reason: reason
        )
    }
}

@MainActor
struct AISuggestionService {
    private let availabilityService: AIAvailabilityService
    private let promptBuilder: AIPromptBuilder
    private let categoryRepository: CategoryRepository
    private let transactionRepository: TransactionRepository

    init(
        availabilityService: AIAvailabilityService,
        promptBuilder: AIPromptBuilder,
        categoryRepository: CategoryRepository,
        transactionRepository: TransactionRepository
    ) {
        self.availabilityService = availabilityService
        self.promptBuilder = promptBuilder
        self.categoryRepository = categoryRepository
        self.transactionRepository = transactionRepository
    }

    func suggest(for transaction: Transaction, categories: [Category]) -> AIStructuredOutput? {
        let text = "\(transaction.merchantCanonicalName ?? "") \(transaction.cleanedDescription)".lowercased()
        let categoryName: String?

        if text.contains("amazon") {
            categoryName = "Compras"
        } else if text.contains("mercadona") || text.contains("carrefour") {
            categoryName = "Alimentacion"
        } else {
            categoryName = nil
        }

        guard let categoryName else { return nil }
        return AIStructuredOutput(
            suggestedCategoryName: categoryName,
            confidence: 0.68,
            explanation: "Suggested conservatively from local merchant and token patterns."
        )
    }

    func suggestWithFoundationModel(for transaction: Transaction, categories: [Category]) async -> AIStructuredOutput? {
        guard availabilityService.isAvailable() else {
            return suggest(for: transaction, categories: categories)
        }

        let resolver = FoundationModelsResolver(
            categoryRepository: categoryRepository,
            transactionRepository: transactionRepository
        )
        let normalized = NormalizedTransactionDTO(
            externalID: transaction.externalID,
            bookingDate: transaction.bookingDate,
            valueDate: transaction.valueDate,
            rawDescription: transaction.rawDescription,
            cleanedDescription: transaction.cleanedDescription,
            merchantDisplayName: transaction.merchantDisplayName,
            merchantCanonicalName: transaction.merchantCanonicalName,
            amount: transaction.amount,
            currencyCode: transaction.currencyCode,
            accountName: transaction.accountName,
            sign: transaction.amount < 0 ? -1 : 1,
            fingerprint: transaction.fingerprint
        )
        let decision = await resolver.resolve(normalized)
        guard let categoryID = decision.categoryID,
              let category = categories.first(where: { $0.id == categoryID }) else {
            return suggest(for: transaction, categories: categories)
        }

        return AIStructuredOutput(
            suggestedCategoryName: category.name,
            confidence: decision.confidence,
            explanation: decision.reason
        )
    }
}
