import Foundation

enum FeatureFlags {
    private static let aiSuggestionsKey = "feature.aiSuggestionsEnabled"
    private static let foundationModelsKey = "feature.foundationModelsEnabled"

    static var aiSuggestionsEnabled: Bool {
        get { value(forKey: aiSuggestionsKey, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: aiSuggestionsKey) }
    }

    static let demoDataEnabled = false
    static let advancedInsightsEnabled = true

    static var foundationModelsEnabled: Bool {
        get { value(forKey: foundationModelsKey, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: foundationModelsKey) }
    }

    private static func value(forKey key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }
}
