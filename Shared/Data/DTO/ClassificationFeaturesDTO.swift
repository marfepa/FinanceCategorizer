import Foundation

struct ClassificationFeaturesDTO {
    let merchantCanonicalName: String?
    let cleanedDescription: String
    let amountBucket: String
    let weekday: Int
    let month: Int
    let accountName: String?
    let sign: Int
    let isRecurringCandidate: Bool
}
