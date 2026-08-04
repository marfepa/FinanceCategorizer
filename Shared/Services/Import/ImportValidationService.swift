import Foundation

struct ImportValidationService {
    func validate(_ preview: ImportPreviewResult) -> Bool {
        !preview.rows.isEmpty && !preview.requiresManualMapping
    }

    func validateForImport(_ preview: ImportPreviewResult) throws {
        guard validate(preview) else {
            throw CSVImportError.invalidHeader
        }
    }
}
