import Foundation

enum ImportColumnField: String, CaseIterable, Identifiable {
    case bookingDate
    case valueDate
    case concept
    case extendedConcept
    case amount
    case balance
    case currency

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookingDate: return "Booking Date"
        case .valueDate: return "Value Date"
        case .concept: return "Concept"
        case .extendedConcept: return "Extended Concept"
        case .amount: return "Amount"
        case .balance: return "Balance"
        case .currency: return "Currency"
        }
    }

    var isRequired: Bool {
        switch self {
        case .bookingDate, .amount:
            return true
        case .valueDate, .concept, .extendedConcept, .balance, .currency:
            return false
        }
    }
}

struct ImportColumnMapping {
    let worksheetName: String?
    let headerRowIndex: Int
    let availableHeaders: [String]
    let bookingDateIndex: Int?
    let valueDateIndex: Int?
    let conceptIndex: Int?
    let extendedConceptIndex: Int?
    let amountIndex: Int?
    let balanceIndex: Int?
    let currencyIndex: Int?

    func index(for field: ImportColumnField) -> Int? {
        switch field {
        case .bookingDate: return bookingDateIndex
        case .valueDate: return valueDateIndex
        case .concept: return conceptIndex
        case .extendedConcept: return extendedConceptIndex
        case .amount: return amountIndex
        case .balance: return balanceIndex
        case .currency: return currencyIndex
        }
    }

    func updating(_ field: ImportColumnField, index: Int?) -> ImportColumnMapping {
        ImportColumnMapping(
            worksheetName: worksheetName,
            headerRowIndex: headerRowIndex,
            availableHeaders: availableHeaders,
            bookingDateIndex: field == .bookingDate ? index : bookingDateIndex,
            valueDateIndex: field == .valueDate ? index : valueDateIndex,
            conceptIndex: field == .concept ? index : conceptIndex,
            extendedConceptIndex: field == .extendedConcept ? index : extendedConceptIndex,
            amountIndex: field == .amount ? index : amountIndex,
            balanceIndex: field == .balance ? index : balanceIndex,
            currencyIndex: field == .currency ? index : currencyIndex
        )
    }

    var hasMinimumRequiredFields: Bool {
        (bookingDateIndex != nil || valueDateIndex != nil) && amountIndex != nil
    }

    var uniqueMappedColumnCount: Int {
        Set([
            bookingDateIndex,
            valueDateIndex,
            conceptIndex,
            extendedConceptIndex,
            amountIndex,
            balanceIndex,
            currencyIndex
        ].compactMap { $0 }).count
    }

    var hasReliableAutomaticMapping: Bool {
        hasMinimumRequiredFields && uniqueMappedColumnCount >= 2
    }

    var debugDescription: String {
        [
            "headerRow=\(headerRowIndex + 1)",
            "bookingDate=\(bookingDateIndex.map { String($0 + 1) } ?? "-")",
            "valueDate=\(valueDateIndex.map { String($0 + 1) } ?? "-")",
            "concept=\(conceptIndex.map { String($0 + 1) } ?? "-")",
            "extendedConcept=\(extendedConceptIndex.map { String($0 + 1) } ?? "-")",
            "amount=\(amountIndex.map { String($0 + 1) } ?? "-")",
            "balance=\(balanceIndex.map { String($0 + 1) } ?? "-")",
            "currency=\(currencyIndex.map { String($0 + 1) } ?? "-")"
        ].joined(separator: " • ")
    }
}

enum ImportRowSeverity: String {
    case warning
    case error
}

struct ImportRowIssue: Identifiable, Error {
    let id = UUID()
    let rowNumber: Int
    let severity: ImportRowSeverity
    let message: String
    let rawValuesSummary: String
}

enum ImportRowStatus: String {
    case ok
    case warning
}

struct ImportPreviewRow: Identifiable {
    let id = UUID()
    let rowNumber: Int
    let bookingDate: Date
    let valueDate: Date?
    let rawConcept: String
    let concept: String
    let amount: Decimal
    let balance: Decimal?
    let currencyCode: String?
    let status: ImportRowStatus
}

struct ImportDiagnostics {
    let sourceType: String
    let worksheetName: String?
    let delimiter: String?
    let headerRowIndex: Int?
    let mappedColumnsDescription: String?
    let rawRowCount: Int
    let validRowCount: Int
    let invalidRowCount: Int
    let importableRowCount: Int
}

struct ImportDuplicateInfo {
    let previousFileName: String
    let importedAt: Date
    let importedRowCount: Int
    let reason: String
}

struct ImportPreviewResult {
    let rows: [ImportPreviewRow]
    let invalidRows: [ImportRowIssue]
    let diagnostics: ImportDiagnostics
    let mapping: ImportColumnMapping?
    let requiresManualMapping: Bool
    let duplicateInfo: ImportDuplicateInfo?
}

struct ImportSummary {
    let sourceFileName: String
    let sourceType: String
    let rawRowCount: Int
    let validRowCount: Int
    let invalidRowCount: Int
    let importedCount: Int
    let autoCategorizedCount: Int
    let duplicatesSkipped: Int
    let pendingReviewCount: Int
    let detectedAccounts: Int
    let dateRangeText: String
}

typealias ImportBatchResult = ImportSummary
