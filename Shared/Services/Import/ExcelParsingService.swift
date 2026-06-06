import Foundation

enum CSVImportError: LocalizedError {
    case emptyInput
    case invalidHeader

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Paste a CSV with at least one transaction row."
        case .invalidHeader:
            return "The file must include recognizable columns for date and amount, such as Fecha/F. valor and Importe."
        }
    }
}

struct RawImportTable {
    let sourceType: String
    let worksheetName: String?
    let delimiter: String?
    let rows: [[String]]
}

struct ImportPreviewBuilder {
    func buildPreview(
        from table: RawImportTable,
        mapping: ImportColumnMapping?,
        requiresManualMapping: Bool
    ) -> ImportPreviewResult {
        guard let mapping else {
            let candidate = BankColumnAutoMapper().detectHeaderCandidate(in: table.rows)
            return ImportPreviewResult(
                rows: [],
                invalidRows: [],
                diagnostics: ImportDiagnostics(
                    sourceType: table.sourceType,
                    worksheetName: table.worksheetName,
                    delimiter: table.delimiter,
                    headerRowIndex: candidate?.rowIndex,
                    mappedColumnsDescription: nil,
                    rawRowCount: table.rows.count,
                    validRowCount: 0,
                    invalidRowCount: 0,
                    importableRowCount: 0
                ),
                mapping: candidate.map {
                    BankColumnAutoMapper().mapping(from: $0, worksheetName: table.worksheetName)
                },
                requiresManualMapping: true,
                duplicateInfo: nil
            )
        }

        var validRows: [ImportPreviewRow] = []
        var invalidRows: [ImportRowIssue] = []

        for (offset, row) in table.rows.dropFirst(mapping.headerRowIndex + 1).enumerated() {
            let sourceRowNumber = mapping.headerRowIndex + 2 + offset
            let normalizedRow = normalizedRowWidth(row, using: mapping)
            let result = parseRow(normalizedRow, rowNumber: sourceRowNumber, using: mapping)
            switch result {
            case .success(let previewRow):
                validRows.append(previewRow)
            case .failure(let issue):
                if !issue.rawValuesSummary.isEmpty || !row.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    invalidRows.append(issue)
                }
            }
        }

        let hasTooFewValidRows = validRows.count < 2 && !table.rows.isEmpty

        return ImportPreviewResult(
            rows: validRows,
            invalidRows: invalidRows,
            diagnostics: ImportDiagnostics(
                sourceType: table.sourceType,
                worksheetName: table.worksheetName,
                delimiter: table.delimiter,
                headerRowIndex: mapping.headerRowIndex,
                mappedColumnsDescription: mapping.debugDescription,
                rawRowCount: table.rows.count,
                validRowCount: validRows.count,
                invalidRowCount: invalidRows.count,
                importableRowCount: validRows.count
            ),
            mapping: mapping,
            requiresManualMapping: requiresManualMapping || !mapping.hasMinimumRequiredFields || hasTooFewValidRows,
            duplicateInfo: nil
        )
    }

    private func parseRow(_ row: [String], rowNumber: Int, using mapping: ImportColumnMapping) -> Result<ImportPreviewRow, ImportRowIssue> {
        let rawConcept = firstNonEmpty([
            value(at: mapping.conceptIndex, in: row),
            value(at: mapping.extendedConceptIndex, in: row)
        ]) ?? ""

        let dateText = firstNonEmpty([
            value(at: mapping.bookingDateIndex, in: row),
            value(at: mapping.valueDateIndex, in: row)
        ])
        let valueDateText = value(at: mapping.valueDateIndex, in: row)
        let amountText = value(at: mapping.amountIndex, in: row)
        let balanceText = value(at: mapping.balanceIndex, in: row)
        let currencyText = value(at: mapping.currencyIndex, in: row)
        let rawValuesSummary = row.joined(separator: " | ").trimmingCharacters(in: .whitespacesAndNewlines)

        if rawValuesSummary.isEmpty {
            return .failure(
                ImportRowIssue(rowNumber: rowNumber, severity: .warning, message: "Empty row", rawValuesSummary: "")
            )
        }

        guard let dateText, let bookingDate = ImportValueParser.parseDate(dateText) else {
            return .failure(
                ImportRowIssue(
                    rowNumber: rowNumber,
                    severity: .error,
                    message: "Row has no valid date",
                    rawValuesSummary: rawValuesSummary
                )
            )
        }

        guard let amountText, let amount = ImportValueParser.parseAmount(amountText) else {
            return .failure(
                ImportRowIssue(
                    rowNumber: rowNumber,
                    severity: .error,
                    message: "Amount could not be parsed",
                    rawValuesSummary: rawValuesSummary
                )
            )
        }

        let concept = rawConcept.isEmpty ? "Movimiento bancario" : rawConcept
        let valueDate = valueDateText.flatMap(ImportValueParser.parseDate)
        let balance = balanceText.flatMap(ImportValueParser.parseAmount)
        let currency = currencyText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? currencyText?.uppercased() : nil
        let status: ImportRowStatus = rawConcept.isEmpty ? .warning : .ok

        return .success(
            ImportPreviewRow(
                rowNumber: rowNumber,
                bookingDate: bookingDate,
                valueDate: valueDate,
                rawConcept: rawConcept,
                concept: concept,
                amount: amount,
                balance: balance,
                currencyCode: currency,
                status: status
            )
        )
    }

    private func value(at index: Int?, in row: [String]) -> String? {
        guard let index, row.indices.contains(index) else { return nil }
        let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        values.first { value in
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? nil
    }

    private func normalizedRowWidth(_ row: [String], using mapping: ImportColumnMapping) -> [String] {
        let expectedCount = max(mapping.availableHeaders.count, 1)

        if row.count == expectedCount {
            return row
        }

        if row.count < expectedCount {
            return row + Array(repeating: "", count: expectedCount - row.count)
        }

        guard let mergeIndex = mergeCandidateIndex(using: mapping) else {
            return Array(row.prefix(expectedCount))
        }

        let rightProtectedIndices = [
            mapping.amountIndex,
            mapping.balanceIndex,
            mapping.currencyIndex
        ]
        .compactMap { $0 }
        .filter { $0 > mergeIndex }
        .sorted()

        let trailingCount = expectedCount - (rightProtectedIndices.first ?? expectedCount)
        let safeTrailingCount = max(0, min(trailingCount, row.count - mergeIndex - 1))
        let leftSlice = Array(row.prefix(mergeIndex))
        let trailingSlice = safeTrailingCount > 0 ? Array(row.suffix(safeTrailingCount)) : []
        let middleStart = mergeIndex
        let middleEnd = row.count - safeTrailingCount

        guard middleStart < middleEnd else {
            return Array(row.prefix(expectedCount))
        }

        let mergedCell = row[middleStart..<middleEnd]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        var normalized = leftSlice + [mergedCell] + trailingSlice

        if normalized.count < expectedCount {
            normalized += Array(repeating: "", count: expectedCount - normalized.count)
        }

        if normalized.count > expectedCount {
            normalized = Array(normalized.prefix(expectedCount))
        }

        return normalized
    }

    private func mergeCandidateIndex(using mapping: ImportColumnMapping) -> Int? {
        if let extendedConceptIndex = mapping.extendedConceptIndex {
            return extendedConceptIndex
        }
        if let conceptIndex = mapping.conceptIndex {
            return conceptIndex
        }
        return nil
    }
}

enum ImportValueParser {
    static func parseDate(_ value: String) -> Date? {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
        let formats = ["yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy", "yyyy/MM/dd", "dd.MM.yyyy", "MM/dd/yyyy"]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format

            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        if let serial = Double(trimmed), serial > 20_000 {
            let excelReferenceDate = Date(timeIntervalSince1970: -2209161600)
            return Calendar.current.date(byAdding: .day, value: Int(serial) - 2, to: excelReferenceDate)
        }

        return nil
    }

    static func parseAmount(_ value: String) -> Decimal? {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ";", with: "")
            .replacingOccurrences(of: "'", with: "")

        guard !trimmed.isEmpty else { return nil }

        let isNegative = trimmed.hasPrefix("-") || trimmed.hasSuffix("-") || (trimmed.hasPrefix("(") && trimmed.hasSuffix(")"))
        let unsigned = trimmed
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")

        let normalized = normalizedNumberString(from: unsigned)
        let signedValue = isNegative && !normalized.hasPrefix("-") ? "-" + normalized : normalized

        return Decimal(string: signedValue, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func normalizedNumberString(from value: String) -> String {
        let lastComma = value.lastIndex(of: ",")
        let lastDot = value.lastIndex(of: ".")

        if let decimalIndex = [lastComma, lastDot].compactMap({ $0 }).max() {
            let fractionalStart = value.index(after: decimalIndex)
            let integerPart = value[..<decimalIndex].filter(\.isNumber)
            let fractionalPart = value[fractionalStart...].filter(\.isNumber)

            if fractionalPart.isEmpty {
                return String(integerPart)
            }

            return "\(integerPart).\(fractionalPart)"
        }

        return String(value.filter(\.isNumber))
    }
}

struct CSVParsingService {
    private let mapper = BankColumnAutoMapper()
    private let previewBuilder = ImportPreviewBuilder()

    func parseTable(text: String) throws -> RawImportTable {
        let sanitized = text.replacingOccurrences(of: "\u{feff}", with: "")
        let lines = physicalLines(in: sanitized)

        guard !lines.isEmpty else {
            throw CSVImportError.emptyInput
        }

        let delimiter = bestDelimiter(in: lines)
        let rows = parseRowsWithFallback(from: sanitized, physicalLines: lines, delimiter: delimiter)
        return RawImportTable(sourceType: "csv", worksheetName: nil, delimiter: String(delimiter), rows: rows)
    }

    func preview(text: String, overrideMapping: ImportColumnMapping? = nil) throws -> ImportPreviewResult {
        let sanitized = text.replacingOccurrences(of: "\u{feff}", with: "")
        let lines = physicalLines(in: sanitized)

        guard !lines.isEmpty else {
            throw CSVImportError.emptyInput
        }

        let previews = try delimiterCandidates(in: lines).map { delimiter -> ImportPreviewResult in
            let table = RawImportTable(
                sourceType: "csv",
                worksheetName: nil,
                delimiter: String(delimiter),
                rows: parseRowsWithFallback(from: sanitized, physicalLines: lines, delimiter: delimiter)
            )
            let mapping = try resolvedMapping(for: table, overrideMapping: overrideMapping)
            return previewBuilder.buildPreview(
                from: table,
                mapping: mapping,
                requiresManualMapping: overrideMapping != nil
            )
        }

        if let best = previews.max(by: { score(for: $0) < score(for: $1) }) {
            return best
        }

        let table = try parseTable(text: text)
        let mapping = try resolvedMapping(for: table, overrideMapping: overrideMapping)
        return previewBuilder.buildPreview(from: table, mapping: mapping, requiresManualMapping: overrideMapping != nil)
    }

    private func resolvedMapping(for table: RawImportTable, overrideMapping: ImportColumnMapping?) throws -> ImportColumnMapping? {
        if let overrideMapping {
            let candidate = mapper.detectHeaderCandidate(in: table.rows)
            if let candidate {
                return mapper.mapping(from: candidate, worksheetName: nil, overrides: overrideDictionary(from: overrideMapping))
            }
            return overrideMapping
        }

        guard let mapping = try? mapper.detectMapping(in: table.rows), mapping.hasReliableAutomaticMapping else {
            return nil
        }
        return mapping
    }

    private func overrideDictionary(from mapping: ImportColumnMapping) -> [ImportColumnField: Int?] {
        [
            .bookingDate: mapping.bookingDateIndex,
            .valueDate: mapping.valueDateIndex,
            .concept: mapping.conceptIndex,
            .extendedConcept: mapping.extendedConceptIndex,
            .amount: mapping.amountIndex,
            .balance: mapping.balanceIndex,
            .currency: mapping.currencyIndex
        ]
    }

    private func bestDelimiter(in lines: [String]) -> Character {
        delimiterCandidates(in: lines).first ?? ";"
    }

    private func delimiterCandidates(in lines: [String]) -> [Character] {
        let candidates: [Character] = [";", ",", "\t"]
        return candidates.sorted { lhs, rhs in
            score(for: lhs, in: lines) > score(for: rhs, in: lines)
        }
    }

    private func score(for delimiter: Character, in lines: [String]) -> Int {
        let sampleRows = lines.prefix(25).map { splitCSVLine($0, delimiter: delimiter) }
        let widths = sampleRows.map(\.count).filter { $0 > 1 }
        let dominantWidthFrequency = Dictionary(grouping: widths, by: { $0 })
            .values
            .map(\.count)
            .max() ?? 0
        let averageWidth = widths.isEmpty ? 0 : widths.reduce(0, +) / widths.count
        let headerCandidateScore = mapper.detectHeaderCandidate(in: sampleRows)?.score ?? 0
        let minimumFieldsBonus = (try? mapper.detectMapping(in: sampleRows))?.hasMinimumRequiredFields == true ? 50 : 0

        return minimumFieldsBonus + (headerCandidateScore * 20) + (dominantWidthFrequency * 8) + averageWidth
    }

    private func score(for preview: ImportPreviewResult) -> Int {
        guard preview.mapping?.hasReliableAutomaticMapping == true else {
            return preview.rows.isEmpty ? -10_000 : (preview.rows.count * 25)
        }

        if preview.rows.isEmpty, !preview.invalidRows.isEmpty {
            return -5_000
        }

        let validWeight = preview.rows.count * 100
        let invalidPenalty = preview.invalidRows.count * 25
        let mappingBonus = 150 + ((preview.mapping?.uniqueMappedColumnCount ?? 0) * 10)
        let manualPenalty = preview.requiresManualMapping ? 75 : 0
        return validWeight + mappingBonus - invalidPenalty - manualPenalty
    }

    private func separatorCount(in line: String, separator: Character) -> Int {
        var count = 0
        var insideQuotes = false
        for character in line {
            if character == "\"" {
                insideQuotes.toggle()
            } else if character == separator && !insideQuotes {
                count += 1
            }
        }
        return count
    }

    private func physicalLines(in text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func parseRowsWithFallback(from text: String, physicalLines: [String], delimiter: Character) -> [[String]] {
        let primaryRows = parseRows(from: text, delimiter: delimiter)
        if primaryRows.count > 1 || physicalLines.count <= 1 {
            return primaryRows
        }

        let recoveredRows = parseRowsByBalancedQuotes(from: physicalLines, delimiter: delimiter)
        return recoveredRows.count > primaryRows.count ? recoveredRows : primaryRows
    }

    private func parseRows(from text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var isInsideQuotes = false
        var fieldStarted = false
        let characters = Array(text)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                let nextIndex = index + 1
                if isInsideQuotes {
                    if nextIndex < characters.count, characters[nextIndex] == "\"" {
                        currentField.append("\"")
                        fieldStarted = true
                        index += 2
                        continue
                    }

                    if nextIndex == characters.count ||
                        characters[nextIndex] == delimiter ||
                        characters[nextIndex] == "\n" ||
                        characters[nextIndex] == "\r" {
                        isInsideQuotes = false
                        index += 1
                        continue
                    }

                    currentField.append(character)
                    fieldStarted = true
                    index += 1
                    continue
                } else if !fieldStarted && currentField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isInsideQuotes = true
                    fieldStarted = true
                    index += 1
                    continue
                } else {
                    currentField.append(character)
                    fieldStarted = true
                    index += 1
                    continue
                }
            }

            if character == delimiter, !isInsideQuotes {
                currentRow.append(currentField)
                currentField = ""
                fieldStarted = false
                index += 1
                continue
            }

            if (character == "\n" || character == "\r"), !isInsideQuotes {
                if character == "\r", index + 1 < characters.count, characters[index + 1] == "\n" {
                    index += 1
                }

                currentRow.append(currentField)
                if currentRow.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow = []
                currentField = ""
                fieldStarted = false
                index += 1
                continue
            }

            currentField.append(character)
            fieldStarted = true
            index += 1
        }

        currentRow.append(currentField)
        if currentRow.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            rows.append(currentRow)
        }

        return rows
    }

    private func parseRowsByBalancedQuotes(from lines: [String], delimiter: Character) -> [[String]] {
        var logicalRows: [String] = []
        var buffer = ""
        var quoteParity = 0

        for line in lines {
            if buffer.isEmpty {
                buffer = line
            } else {
                buffer.append("\n")
                buffer.append(line)
            }

            quoteParity = (quoteParity + quoteDelta(in: line)) % 2

            if quoteParity == 0 {
                logicalRows.append(buffer)
                buffer = ""
                quoteParity = 0
            }
        }

        if !buffer.isEmpty {
            logicalRows.append(buffer)
        }

        return logicalRows.map { splitCSVLine($0, delimiter: delimiter) }
    }

    private func quoteDelta(in line: String) -> Int {
        var delta = 0
        var previousWasQuote = false

        for character in line {
            if character == "\"" {
                if previousWasQuote {
                    previousWasQuote = false
                    continue
                }
                delta += 1
                previousWasQuote = true
            } else {
                previousWasQuote = false
            }
        }

        return delta % 2
    }

    private func splitCSVLine(_ line: String, delimiter: Character) -> [String] {
        var values: [String] = []
        var current = ""
        var isInsideQuotes = false

        for character in line {
            if character == "\"" {
                isInsideQuotes.toggle()
            } else if character == delimiter && !isInsideQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        values.append(current)
        return values
    }
}
