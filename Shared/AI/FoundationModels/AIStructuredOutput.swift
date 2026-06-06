import Foundation
struct AICategorizationDecision {
    var merchant: String
    var categoryName: String
    var subcategoryName: String?
    var confidence: Double
    var isRecurring: Bool
    var shouldSuggestRule: Bool
    var reason: String
}

struct AIStructuredOutput {
    let suggestedCategoryName: String
    let confidence: Double
    let explanation: String
}
