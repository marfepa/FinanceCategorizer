import Foundation

@MainActor
final class RuleEngine {
    private let ruleRepository: RuleRepository

    init(ruleRepository: RuleRepository) {
        self.ruleRepository = ruleRepository
    }

    func match(_ input: NormalizedTransactionDTO) -> CategorizationDecision? {
        guard let rules = try? ruleRepository.fetchActiveRules(), !rules.isEmpty else {
            return nil
        }

        for rule in rules {
            if let merchantContains = rule.merchantContains,
               !(input.merchantCanonicalName ?? input.cleanedDescription).lowercased().contains(merchantContains.lowercased()) {
                continue
            }

            if let descriptionContains = rule.descriptionContains {
                let normPattern = descriptionContains.lowercased()
                let cleaned = input.cleanedDescription.lowercased()
                if normPattern.isGenericBankingNoise {
                    if cleaned != normPattern {
                        continue
                    }
                } else if !cleaned.contains(normPattern) {
                    continue
                }
            }

            let comparableAmount = abs(input.amount)
            if let amountMin = rule.amountMin, comparableAmount < abs(amountMin) {
                continue
            }

            if let amountMax = rule.amountMax, comparableAmount > abs(amountMax) {
                continue
            }

            if let amountSign = rule.amountSign, amountSign != input.sign {
                continue
            }

            return CategorizationDecision(
                categoryID: rule.targetCategoryID,
                subcategoryID: rule.targetSubcategoryID,
                source: .rule,
                confidence: 0.99,
                shouldQueueForReview: false,
                isRecurringCandidate: false,
                reason: "Matched rule '\(rule.name)'."
            )
        }

        return nil
    }
}
