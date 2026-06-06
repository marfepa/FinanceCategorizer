import Foundation

struct MerchantLearningService {
    func learnAlias(from concept: String) -> String {
        concept.lowercased()
    }
}
