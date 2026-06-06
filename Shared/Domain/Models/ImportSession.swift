import Foundation
import SwiftData

@Model
final class ImportBatch {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var sourceType: String
    var importedAt: Date
    var rawRowCount: Int
    var validRowCount: Int
    var importedRowCount: Int
    var duplicatesSkipped: Int
    var pendingReviewCount: Int
    var fileFingerprint: String?
    var rowFingerprint: String?
    var dateRangeText: String?

    init(
        id: UUID = UUID(),
        fileName: String,
        sourceType: String = "unknown",
        importedAt: Date = .now,
        rawRowCount: Int = 0,
        validRowCount: Int = 0,
        importedRowCount: Int = 0,
        duplicatesSkipped: Int = 0,
        pendingReviewCount: Int = 0,
        fileFingerprint: String? = nil,
        rowFingerprint: String? = nil,
        dateRangeText: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.sourceType = sourceType
        self.importedAt = importedAt
        self.rawRowCount = rawRowCount
        self.validRowCount = validRowCount
        self.importedRowCount = importedRowCount
        self.duplicatesSkipped = duplicatesSkipped
        self.pendingReviewCount = pendingReviewCount
        self.fileFingerprint = fileFingerprint
        self.rowFingerprint = rowFingerprint
        self.dateRangeText = dateRangeText
    }
}
