import Foundation

enum CategorizationSource: String, Codable, CaseIterable {
    case rule
    case merchantMemory
    case localML
    case foundationModel
    case manual
    case unknown
}
