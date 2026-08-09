import Foundation
import os

protocol ImportOrchestrating {
    func importFile(from url: URL, language: AppLanguage) async throws -> ImportSummary
}
enum DuplicateImportError: LocalizedError {
    case alreadyImported(ImportDuplicateInfo)

    var errorDescription: String? {
        switch self {
        case .alreadyImported(let info):
            let language = AppLanguage.currentSelection
            return language.localized(
                "import.error.duplicateFile",
                info.reason,
                info.previousFileName,
                language.format(date: info.importedAt, dateStyle: .medium, timeStyle: .short)
            )
        }
    }
}

@MainActor
final class ImportOrchestrator: ImportOrchestrating {
    private let transactionRepository: TransactionRepository
    private let categoryRepository: CategoryRepository
    private let importBatchRepository: ImportBatchRepository
    private let categorizer: CategorizationOrchestrating
    private let normalizer: TransactionNormalizing
    private let fileImportService: FileImportService
    private let csvParsingService: CSVParsingService
    private let xlsxParsingService: XLSXParsingService
    private let pdfParsingService: PDFParsingService
    private let validationService: ImportValidationService
    private let insightEngine: InsightEngine
    private let localModelManager: LocalModelManager
    private let duplicateMovementDetector: DuplicateMovementDetector

    init(
        transactionRepository: TransactionRepository,
        categoryRepository: CategoryRepository,
        importBatchRepository: ImportBatchRepository,
        categorizer: CategorizationOrchestrating,
        normalizer: TransactionNormalizing,
        fileImportService: FileImportService,
        csvParsingService: CSVParsingService,
        xlsxParsingService: XLSXParsingService,
        pdfParsingService: PDFParsingService,
        validationService: ImportValidationService,
        insightEngine: InsightEngine,
        localModelManager: LocalModelManager,
        duplicateMovementDetector: DuplicateMovementDetector = DuplicateMovementDetector()
    ) {
        self.transactionRepository = transactionRepository
        self.categoryRepository = categoryRepository
        self.importBatchRepository = importBatchRepository
        self.categorizer = categorizer
        self.normalizer = normalizer
        self.fileImportService = fileImportService
        self.csvParsingService = csvParsingService
        self.xlsxParsingService = xlsxParsingService
        self.pdfParsingService = pdfParsingService
        self.validationService = validationService
        self.insightEngine = insightEngine
        self.localModelManager = localModelManager
        self.duplicateMovementDetector = duplicateMovementDetector
    }

    func previewCSV(_ text: String, overrideMapping: ImportColumnMapping? = nil) throws -> ImportPreviewResult {
        let preview = try csvParsingService.preview(text: text, overrideMapping: overrideMapping)
        return try attachDuplicateInfo(to: preview, fileFingerprint: nil)
    }

    func previewFile(at url: URL, overrideMapping: ImportColumnMapping? = nil) throws -> ImportPreviewResult {
        let fileData = try fileImportService.readData(from: url)
        let fileFingerprint = fileImportService.fingerprint(for: fileData)
        let result: ImportPreviewResult = try fileImportService.withAccess(to: url) {
            switch try fileImportService.format(for: url) {
            case .csv:
                let text = try fileImportService.readText(from: url)
                return try csvParsingService.preview(text: text, overrideMapping: overrideMapping)
            case .xlsx:
                return try xlsxParsingService.preview(fileURL: url, overrideMapping: overrideMapping)
            case .pdf:
                let text = try fileImportService.readPDFText(from: url)
                return try pdfParsingService.preview(text: text)
            }
        }

        return try attachDuplicateInfo(to: result, fileFingerprint: fileFingerprint)
    }

    func importFile(from url: URL, language: AppLanguage) async throws -> ImportSummary {
        let preview = try previewFile(at: url)
        let fileData = try fileImportService.readData(from: url)
        return try await importPreview(
            preview,
            sourceFileName: url.lastPathComponent,
            sourceType: "file",
            fileFingerprint: fileImportService.fingerprint(for: fileData),
            language: language
        )
    }

    @discardableResult
    func importCSV(
        _ text: String,
        sourceFileName: String,
        language: AppLanguage,
        preview: ImportPreviewResult? = nil,
        accountName: String? = nil,
        progress: @MainActor @Sendable (Double) -> Void = { _ in }
    ) async throws -> ImportSummary {
        let resolvedPreview = if let preview { preview } else { try previewCSV(text) }
        return try await importPreview(resolvedPreview, sourceFileName: sourceFileName, sourceType: "csv", fileFingerprint: nil, accountName: accountName, language: language, progress: progress)
    }

    @discardableResult
    func importFile(
        at url: URL,
        language: AppLanguage,
        preview: ImportPreviewResult? = nil,
        accountName: String? = nil,
        progress: @MainActor @Sendable (Double) -> Void = { _ in }
    ) async throws -> ImportSummary {
        let resolvedPreview = if let preview { preview } else { try self.previewFile(at: url) }
        let fileFingerprint = try fileImportService.fingerprint(for: fileImportService.readData(from: url))
        return try await importPreview(resolvedPreview, sourceFileName: url.lastPathComponent, sourceType: "file", fileFingerprint: fileFingerprint, accountName: accountName, language: language, progress: progress)
    }

    private func importPreview(
        _ preview: ImportPreviewResult,
        sourceFileName: String,
        sourceType: String,
        fileFingerprint: String?,
        accountName: String? = nil,
        language: AppLanguage,
        progress: @MainActor @Sendable (Double) -> Void = { _ in }
    ) async throws -> ImportSummary {
        try validationService.validateForImport(preview)
        if let duplicateInfo = preview.duplicateInfo {
            throw DuplicateImportError.alreadyImported(duplicateInfo)
        }
        progress(0.08)
        return try await importRows(preview, sourceFileName: sourceFileName, sourceType: sourceType, fileFingerprint: fileFingerprint, accountName: accountName, language: language, progress: progress)
    }

    private func importRows(
        _ preview: ImportPreviewResult,
        sourceFileName: String,
        sourceType: String,
        fileFingerprint: String?,
        accountName: String?,
        language: AppLanguage,
        progress: @MainActor @Sendable (Double) -> Void
    ) async throws -> ImportSummary {
        try Task.checkCancellation()
        try categoryRepository.ensureBaseCategories()
        let localizedSourceType = language.localized(sourceType == "csv" ? "import.source.csv" : "import.source.file")
        var importedCount = 0
        var autoCategorizedCount = 0
        var duplicatesSkipped = 0
        var pendingReviewCount = 0
        var importedTransactions: [Transaction] = []
        let importBatchID = UUID()

        let sortedDates = preview.rows.map(\.bookingDate).sorted()
        let existingCandidates: [DuplicateMovementCandidate]
        if let start = sortedDates.first, let end = sortedDates.last {
            // Pad by 7 days to catch duplicate transactions slightly offset in dates
            let paddedStart = Calendar.current.date(byAdding: .day, value: -7, to: start) ?? start
            let paddedEnd = Calendar.current.date(byAdding: .day, value: 7, to: end) ?? end
            existingCandidates = try transactionRepository
                .fetchByDateRange(start: paddedStart, end: paddedEnd)
                .map(DuplicateMovementCandidate.init(transaction:))
        } else {
            existingCandidates = []
        }
        var normalizedRows: [NormalizedTransactionDTO] = []
        var candidatesForImport: [DuplicateMovementCandidate] = []

        for (index, row) in preview.rows.enumerated() {
            try Task.checkCancellation()
            let parsed = ParsedRowDTO(
                externalID: nil,
                bookingDate: row.bookingDate,
                valueDate: row.valueDate,
                description: row.concept,
                amount: row.amount,
                balance: row.balance,
                currencyCode: row.currencyCode ?? AppConfig.defaultCurrencyCode,
                accountName: accountName
            )
            let normalized = normalizer.normalize(parsed)
            normalizedRows.append(normalized)
            candidatesForImport.append(
                DuplicateMovementCandidate(normalized: normalized, importBatchID: importBatchID)
            )
            if index.isMultiple(of: 50) {
                progress(0.08 + (Double(index + 1) / Double(max(preview.rows.count, 1))) * 0.17)
                await Task.yield()
            }
        }

        let duplicateMatches = duplicateMovementDetector.findMatches(
            for: candidatesForImport,
            against: existingCandidates
        )

        for index in preview.rows.indices {
            try Task.checkCancellation()
            let candidate = candidatesForImport[index]
            if duplicateMatches[candidate.id] != nil {
                duplicatesSkipped += 1
                continue
            }

            let normalized = normalizedRows[index]

            let decision = await categorizer.categorize(normalized)
            let transaction = Transaction(
                importBatchID: importBatchID,
                bookingDate: normalized.bookingDate,
                valueDate: normalized.valueDate,
                rawDescription: normalized.rawDescription,
                cleanedDescription: normalized.cleanedDescription,
                merchantDisplayName: normalized.merchantDisplayName,
                merchantCanonicalName: normalized.merchantCanonicalName,
                amount: normalized.amount,
                balanceAfter: normalized.balance,
                currencyCode: normalized.currencyCode,
                kindRaw: normalized.resolvedKind.rawValue,
                accountName: normalized.accountName,
                categoryID: decision.categoryID,
                subcategoryID: decision.subcategoryID,
                categorizationSourceRaw: decision.source.rawValue,
                confidence: decision.confidence,
                needsReview: decision.shouldQueueForReview,
                reviewStatusRaw: decision.shouldQueueForReview ? ReviewStatus.pending.rawValue : ReviewStatus.accepted.rawValue,
                categorizationReason: decision.reason,
                fingerprint: normalized.fingerprint,
                isRecurringCandidate: decision.isRecurringCandidate
            )

            importedTransactions.append(transaction)
            importedCount += 1

            if decision.categoryID != nil, !decision.shouldQueueForReview {
                autoCategorizedCount += 1
            }

            if decision.shouldQueueForReview {
                pendingReviewCount += 1
            }
            if index.isMultiple(of: 25) || index == preview.rows.indices.last {
                progress(0.25 + (Double(index + 1) / Double(max(preview.rows.count, 1))) * 0.65)
                await Task.yield()
            }
        }

        let formatter = DateIntervalFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateRangeText: String
        if let start = sortedDates.first, let end = sortedDates.last {
            dateRangeText = formatter.string(from: start, to: end)
        } else {
            dateRangeText = language.localized("No date range")
        }

        try Task.checkCancellation()
        progress(0.93)
        try importBatchRepository.commitImport(
            transactions: importedTransactions,
            id: importBatchID,
            fileName: sourceFileName,
            sourceType: sourceType,
            rawRowCount: preview.diagnostics.rawRowCount,
            validRowCount: preview.rows.count,
            importedRowCount: importedCount,
            duplicatesSkipped: duplicatesSkipped,
            pendingReviewCount: pendingReviewCount,
            fileFingerprint: fileFingerprint,
            rowFingerprint: rowFingerprint(for: preview),
            dateRangeText: dateRangeText
        )
        progress(0.97)

        // Derived data must never turn a successful financial-data commit into
        // a reported import failure. It can be rebuilt safely on the next run.
        do {
            try localModelManager.rebuildModelIfNeeded()
            try await insightEngine.refreshInsights(language: language)
        } catch {
            Logger(subsystem: "com.mariofernandez.FinanceCategorizer", category: "Import")
                .error("Post-import refresh failed: \(error.localizedDescription, privacy: .public)")
        }

        progress(1.0)

        return ImportSummary(
            sourceFileName: sourceFileName,
            sourceType: localizedSourceType,
            rawRowCount: preview.diagnostics.rawRowCount,
            validRowCount: preview.rows.count,
            invalidRowCount: preview.invalidRows.count,
            importedCount: importedCount,
            autoCategorizedCount: autoCategorizedCount,
            duplicatesSkipped: duplicatesSkipped,
            pendingReviewCount: pendingReviewCount,
            detectedAccounts: Set(importedTransactions.compactMap(\.accountName)).count,
            dateRangeText: dateRangeText
        )
    }

    private func attachDuplicateInfo(to preview: ImportPreviewResult, fileFingerprint: String?) throws -> ImportPreviewResult {
        let duplicateMatch = try importBatchRepository.findDuplicateBatch(
            fileFingerprint: fileFingerprint,
            rowFingerprint: rowFingerprint(for: preview)
        )

        return ImportPreviewResult(
            rows: preview.rows,
            invalidRows: preview.invalidRows,
            diagnostics: preview.diagnostics,
            mapping: preview.mapping,
            requiresManualMapping: preview.requiresManualMapping,
            duplicateInfo: duplicateMatch.map {
                ImportDuplicateInfo(
                    previousFileName: $0.batch.fileName,
                    importedAt: $0.batch.importedAt,
                    importedRowCount: $0.batch.importedRowCount,
                    reason: $0.reason
                )
            }
        )
    }

    private func rowFingerprint(for preview: ImportPreviewResult) -> String? {
        guard !preview.rows.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        let canonicalRows = preview.rows
            .sorted {
                if $0.bookingDate == $1.bookingDate {
                    if $0.concept == $1.concept {
                        return $0.amount < $1.amount
                    }
                    return $0.concept < $1.concept
                }
                return $0.bookingDate < $1.bookingDate
            }
            .map { row in
                [
                    formatter.string(from: row.bookingDate),
                    row.concept.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    NSDecimalNumber(decimal: row.amount).stringValue,
                    row.currencyCode ?? AppConfig.defaultCurrencyCode
                ].joined(separator: "|")
            }
            .joined(separator: "\n")

        return fileImportService.fingerprint(for: Data(canonicalRows.utf8))
    }
}
