import Foundation
import SwiftData

struct DuplicateImportMatch {
    let batch: ImportBatch
    let reason: String
}

@MainActor
final class ImportBatchRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func saveBatch(
        id: UUID = UUID(),
        fileName: String,
        sourceType: String,
        rawRowCount: Int,
        validRowCount: Int,
        importedRowCount: Int,
        duplicatesSkipped: Int,
        pendingReviewCount: Int,
        fileFingerprint: String? = nil,
        rowFingerprint: String? = nil,
        dateRangeText: String? = nil
    ) throws {
        let context = makeContext()
        context.insert(
            ImportBatch(
                id: id,
                fileName: fileName,
                sourceType: sourceType,
                importedAt: .now,
                rawRowCount: rawRowCount,
                validRowCount: validRowCount,
                importedRowCount: importedRowCount,
                duplicatesSkipped: duplicatesSkipped,
                pendingReviewCount: pendingReviewCount,
                fileFingerprint: fileFingerprint,
                rowFingerprint: rowFingerprint,
                dateRangeText: dateRangeText
            )
        )
        try context.save()
    }

    func fetchRecentBatches(limit: Int = 5) throws -> [ImportBatch] {
        let context = makeContext()
        var descriptor = FetchDescriptor<ImportBatch>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func findDuplicateBatch(fileFingerprint: String?, rowFingerprint: String?) throws -> DuplicateImportMatch? {
        let context = makeContext()
        let batches = try context.fetch(FetchDescriptor<ImportBatch>(sortBy: [SortDescriptor(\.importedAt, order: .reverse)]))

        if let fileFingerprint,
           let batch = batches.first(where: { $0.fileFingerprint == fileFingerprint }) {
            return DuplicateImportMatch(batch: batch, reason: "Exact same file content")
        }

        if let rowFingerprint,
           let batch = batches.first(where: { $0.rowFingerprint == rowFingerprint }) {
            return DuplicateImportMatch(batch: batch, reason: "Same imported movements")
        }

        return nil
    }
}
