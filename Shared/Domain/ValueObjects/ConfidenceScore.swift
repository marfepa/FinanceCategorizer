import Foundation

struct ConfidenceScore: Codable, Equatable {
    let value: Double

    var shouldAutoAccept: Bool { value >= AppConfig.autoCategorizationThreshold }
    var shouldAutoAcceptButMarkSoft: Bool {
        value >= AppConfig.softAutoCategorizationThreshold && value < AppConfig.autoCategorizationThreshold
    }
    var shouldSendToReview: Bool { value < AppConfig.suggestionThreshold }
}
