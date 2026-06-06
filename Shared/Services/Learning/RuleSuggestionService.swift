import Foundation

struct RuleSuggestionService {
    func suggestRuleName(for merchant: String) -> String {
        "Auto rule for \(merchant)"
    }
}
