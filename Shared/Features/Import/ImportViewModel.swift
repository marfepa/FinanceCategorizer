import Foundation
import Observation

@MainActor
@Observable
final class ImportViewModel {
    var csvText = ""
    var sourceFileName = "bank-export.csv"
    var accountName = ""
    var selectedFileURL: URL?
    var lastImportedFileName: String?
    var importedRows = 0
    var previewRows: [ImportPreviewRow] = []
    var invalidRows: [ImportRowIssue] = []
    var statusMessage: String?
    var errorMessage: String?
    var isDropTargeted = false
    var isImporting = false
    var importProgress: Double = 0.0
    var summary: ImportSummary?
    var diagnostics: ImportDiagnostics?
    var currentPreview: ImportPreviewResult?
    var manualMapping: ImportColumnMapping?
    var duplicateInfo: ImportDuplicateInfo?
    private var activeImportTask: Task<ImportSummary, Error>?

    func preview(using container: AppContainer, language: AppLanguage = .currentSelection) {
        guard selectedFileURL != nil || !csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearPreviewState()
            errorMessage = language.localized("import.error.chooseSource")
            statusMessage = nil
            return
        }

        do {
            let preview: ImportPreviewResult
            if let selectedFileURL {
                preview = try container.importOrchestrator.previewFile(at: selectedFileURL, overrideMapping: manualMapping)
            } else {
                preview = try container.importOrchestrator.previewCSV(csvText, overrideMapping: manualMapping)
            }
            apply(preview, language: language)
        } catch {
            clearPreviewState()
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func importTransactions(using container: AppContainer, language: AppLanguage) async {
        guard !isImporting else { return }
        isImporting = true
        importProgress = 0.02
        defer { 
            isImporting = false 
            importProgress = 0.0
        }
        do {
            let preview = try ensuredPreview(using: container)
            if let duplicateInfo = preview.duplicateInfo {
                throw DuplicateImportError.alreadyImported(duplicateInfo)
            }
            let selectedFileURL = selectedFileURL
            let csvText = csvText
            let sourceFileName = sourceFileName
            let accountName = normalizedAccountName
            let task = Task { @MainActor [weak self] in
                let progress: @MainActor @Sendable (Double) -> Void = { value in
                    self?.importProgress = value
                }
                if let selectedFileURL {
                    return try await container.importOrchestrator.importFile(
                        at: selectedFileURL,
                        language: language,
                        preview: preview,
                        accountName: accountName,
                        progress: progress
                    )
                }
                return try await container.importOrchestrator.importCSV(
                    csvText,
                    sourceFileName: sourceFileName,
                    language: language,
                    preview: preview,
                    accountName: accountName,
                    progress: progress
                )
            }
            activeImportTask = task
            let summary = try await task.value
            activeImportTask = nil
            importedRows = summary.importedCount
            lastImportedFileName = summary.sourceFileName
            self.summary = summary
            statusMessage = language.localized(
                "import.status.imported",
                language.formatInteger(summary.importedCount),
                language.formatInteger(summary.duplicatesSkipped)
            )
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch is CancellationError {
            activeImportTask = nil
            statusMessage = language.localized("import.status.cancelled")
            errorMessage = nil
            summary = nil
        } catch {
            activeImportTask = nil
            statusMessage = nil
            errorMessage = error.localizedDescription
            summary = nil
        }
    }

    func cancelImport() {
        activeImportTask?.cancel()
    }

    func loadFile(from url: URL, using container: AppContainer, language: AppLanguage) {
        selectedFileURL = url
        sourceFileName = url.lastPathComponent
        csvText = ""
        clearPreviewState()
        errorMessage = nil
        statusMessage = language.localized("import.status.loading", url.lastPathComponent)

        do {
            csvText = (try? container.fileImportService.readText(from: url)) ?? ""
            let preview = try container.importOrchestrator.previewFile(at: url)
            apply(preview, language: language)
            manualMapping = preview.mapping
            statusMessage = language.localized(
                "import.status.loaded",
                url.lastPathComponent,
                language.formatInteger(preview.rows.count)
            )
        } catch {
            clearPreviewState()
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func updateManualMapping(_ field: ImportColumnField, index: Int?, using container: AppContainer) {
        guard let currentMapping = manualMapping ?? currentPreview?.mapping else { return }
        manualMapping = currentMapping.updating(field, index: index)
        preview(using: container, language: .currentSelection)
    }

    func currentMappingIndex(for field: ImportColumnField) -> Int? {
        manualMapping?.index(for: field) ?? currentPreview?.mapping?.index(for: field)
    }

    func availableHeaders() -> [String] {
        manualMapping?.availableHeaders ?? currentPreview?.mapping?.availableHeaders ?? []
    }

    private func ensuredPreview(using container: AppContainer) throws -> ImportPreviewResult {
        if let currentPreview {
            return currentPreview
        }

        if let selectedFileURL {
            return try container.importOrchestrator.previewFile(at: selectedFileURL, overrideMapping: manualMapping)
        }

        return try container.importOrchestrator.previewCSV(csvText, overrideMapping: manualMapping)
    }

    private var normalizedAccountName: String? {
        let trimmed = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func apply(_ preview: ImportPreviewResult, language: AppLanguage) {
        currentPreview = preview
        previewRows = preview.rows
        invalidRows = preview.invalidRows
        diagnostics = preview.diagnostics
        duplicateInfo = preview.duplicateInfo
        summary = nil
        errorMessage = nil

        if manualMapping == nil {
            manualMapping = preview.mapping
        }

        if preview.rows.isEmpty {
            errorMessage = preview.requiresManualMapping
                ? language.localized("import.error.adjustMapping")
                : language.localized("import.error.noRowsParsed")
        }

        let valid = preview.diagnostics.validRowCount
        let invalid = preview.diagnostics.invalidRowCount
        let worksheet = preview.diagnostics.worksheetName ?? "CSV"
        if let duplicateInfo = preview.duplicateInfo {
            statusMessage = language.localized(
                "import.status.duplicateDetected",
                duplicateInfo.reason,
                duplicateInfo.previousFileName
            )
        } else {
            statusMessage = language.localized(
                "import.status.sourceSummary",
                worksheet,
                language.formatInteger(valid),
                language.formatInteger(invalid)
            )
        }
    }

    private func clearPreviewState() {
        previewRows = []
        invalidRows = []
        currentPreview = nil
        diagnostics = nil
        summary = nil
        manualMapping = nil
        duplicateInfo = nil
    }
}
