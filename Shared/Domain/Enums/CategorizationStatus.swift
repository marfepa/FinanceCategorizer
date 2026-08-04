import Foundation

enum ReviewStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case corrected
    case ignored
}

enum DuplicateReviewStatus: String, Codable, CaseIterable {
    case pending
    case dismissed
    case resolved
}
