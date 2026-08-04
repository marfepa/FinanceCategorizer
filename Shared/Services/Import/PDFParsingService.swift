import Foundation

enum PDFImportError: LocalizedError, Equatable {
    case emptyInput
    case unsupportedBankFormat

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "The PDF did not contain any readable text."
        case .unsupportedBankFormat:
            return "Could not extract transactions. The PDF format of this bank may not be supported yet."
        }
    }
}
struct PDFParsingService {
    
    private let strategies: [PDFBankStrategy] = [
        OpenbankPDFStrategy()
    ]

    // MARK: - Public API

    func preview(text: String) throws -> ImportPreviewResult {
        let rawLines = text.components(separatedBy: .newlines)

        guard !rawLines.isEmpty else {
            throw PDFImportError.emptyInput
        }

        guard let bestStrategy = strategies.max(by: { $0.matches(fullText: text) < $1.matches(fullText: text) }),
              bestStrategy.matches(fullText: text) > 0.5 else {
            throw PDFImportError.unsupportedBankFormat
        }

        let transactions = bestStrategy.extractTransactions(from: rawLines)

        guard !transactions.isEmpty else {
            return ImportPreviewResult(
                rows: [],
                invalidRows: [ImportRowIssue(
                    rowNumber: 0,
                    severity: .error,
                    message: "No complete Openbank movement was found. The statement must expose an operation date and amount; redacted or scanned columns cannot be imported safely.",
                    rawValuesSummary: ""
                )],
                diagnostics: ImportDiagnostics(
                    sourceType: "pdf - \(bestStrategy.bankName)",
                    worksheetName: "\(bestStrategy.bankName) PDF",
                    delimiter: nil,
                    headerRowIndex: nil,
                    mappedColumnsDescription: "Openbank date/concept/amount columns",
                    rawRowCount: rawLines.count,
                    validRowCount: 0,
                    invalidRowCount: 1,
                    importableRowCount: 0
                ),
                mapping: nil,
                requiresManualMapping: true,
                duplicateInfo: nil
            )
        }

        var validRows: [ImportPreviewRow] = []
        var invalidRows: [ImportRowIssue] = []

        for (index, tx) in transactions.enumerated() {
            let rowNumber = index + 1

            guard let bookingDate = ImportValueParser.parseDate(tx.dateStr) else {
                invalidRows.append(ImportRowIssue(
                    rowNumber: rowNumber,
                    severity: .error,
                    message: "Cannot parse date: \(tx.dateStr)",
                    rawValuesSummary: tx.rawText
                ))
                continue
            }

            guard let amount = ImportValueParser.parseAmount(tx.amountStr) else {
                invalidRows.append(ImportRowIssue(
                    rowNumber: rowNumber,
                    severity: .error,
                    message: "Cannot parse amount: \(tx.amountStr)",
                    rawValuesSummary: tx.rawText
                ))
                continue
            }

            let valueDate = tx.valueDateStr.flatMap { ImportValueParser.parseDate($0) }
            let balance = tx.balanceStr.flatMap { ImportValueParser.parseAmount($0) }
            let concept = tx.concept.isEmpty ? "Movimiento \(bestStrategy.bankName)" : tx.concept

            validRows.append(ImportPreviewRow(
                rowNumber: rowNumber,
                bookingDate: bookingDate,
                valueDate: valueDate,
                rawConcept: tx.concept,
                concept: concept,
                amount: amount,
                balance: balance,
                currencyCode: nil,
                status: .ok
            ))
        }

        return ImportPreviewResult(
            rows: validRows,
            invalidRows: invalidRows,
            diagnostics: ImportDiagnostics(
                sourceType: "pdf - \(bestStrategy.bankName)",
                worksheetName: "\(bestStrategy.bankName) PDF",
                delimiter: nil,
                headerRowIndex: nil,
            mappedColumnsDescription: "Openbank date/concept/amount columns",
                rawRowCount: rawLines.count,
                validRowCount: validRows.count,
                invalidRowCount: invalidRows.count,
                importableRowCount: validRows.count
            ),
            mapping: nil,
            requiresManualMapping: invalidRows.contains { $0.severity == .error },
            duplicateInfo: nil
        )
    }
}
