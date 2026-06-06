import Foundation

enum AppConfig {
    static let appName = "Finance Categorizer"
    static let defaultCurrencyCode = "EUR"
    static let autoCategorizationThreshold = 0.92
    static let softAutoCategorizationThreshold = 0.80
    static let suggestionThreshold = 0.65
    static let maxAISuggestions = 3
    static let minimumLocalModelExamplesToTrain = 5
    static let minimumLocalModelExamplesForReadyState = 24
    static let minimumReadyCategories = 3
    static let minimumExamplesPerReadyCategory = 4
}
