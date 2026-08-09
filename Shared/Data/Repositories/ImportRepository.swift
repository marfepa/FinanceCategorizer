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

    /// Persists the imported movements and their audit batch in one SwiftData
    /// save. A failed commit therefore cannot leave untracked movements behind.
    func commitImport(
        transactions: [Transaction],
        id: UUID,
        fileName: String,
        sourceType: String,
        rawRowCount: Int,
        validRowCount: Int,
        importedRowCount: Int,
        duplicatesSkipped: Int,
        pendingReviewCount: Int,
        fileFingerprint: String?,
        rowFingerprint: String?,
        dateRangeText: String?
    ) throws {
        let context = makeContext()
        transactions.forEach(context.insert)

        if let accountName = transactions.compactMap(\.accountName).first {
            let targetName = accountName
            let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.name == targetName })
            let latestBalanceTransaction = transactions
                .filter { $0.balanceAfter != nil }
                .max { $0.bookingDate < $1.bookingDate }
            let currencyCode = latestBalanceTransaction?.currencyCode
                ?? transactions.first?.currencyCode
                ?? AppConfig.defaultCurrencyCode

            if let existing = try context.fetch(descriptor).first {
                existing.currencyCode = currencyCode
                if let latestBalanceTransaction,
                   let balance = latestBalanceTransaction.balanceAfter {
                    existing.currentBalance = balance
                    existing.balanceAsOf = latestBalanceTransaction.bookingDate
                    existing.balanceSourceRaw = "import"
                }
            } else {
                context.insert(
                    Account(
                        name: accountName,
                        currencyCode: currencyCode,
                        currentBalance: latestBalanceTransaction?.balanceAfter,
                        balanceAsOf: latestBalanceTransaction?.bookingDate,
                        balanceSourceRaw: latestBalanceTransaction == nil ? nil : "import"
                    )
                )
            }
        }

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
        
        if let fileFingerprint {
            var descriptor = FetchDescriptor<ImportBatch>(
                predicate: #Predicate { $0.fileFingerprint == fileFingerprint },
                sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            if let batch = try context.fetch(descriptor).first {
                return DuplicateImportMatch(batch: batch, reason: "Exact same file content")
            }
        }

        if let rowFingerprint {
            var descriptor = FetchDescriptor<ImportBatch>(
                predicate: #Predicate { $0.rowFingerprint == rowFingerprint },
                sortBy: [SortDescriptor(\.importedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            if let batch = try context.fetch(descriptor).first {
                return DuplicateImportMatch(batch: batch, reason: "Same imported movements")
            }
        }

        return nil
    }
}
