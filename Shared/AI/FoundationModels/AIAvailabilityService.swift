import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelsAvailability {
    static func isUsable() -> Bool {
        #if canImport(FoundationModels)
        guard FeatureFlags.aiSuggestionsEnabled, FeatureFlags.foundationModelsEnabled else {
            return false
        }
        if #available(macOS 26.0, iOS 26.0, *) {
            let model = SystemLanguageModel.default
            if case .available = model.availability {
                return true
            }
        }
        #endif
        return false
    }
}

struct AIAvailabilityService {
    func isAvailable() -> Bool {
        FoundationModelsAvailability.isUsable()
    }
}
