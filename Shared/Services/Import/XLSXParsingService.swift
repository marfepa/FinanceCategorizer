import Foundation
import ZIPFoundation

enum XLSXParsingError: LocalizedError {
    case missingWorksheet
    case invalidArchive

    var errorDescription: String? {
        switch self {
        case .missingWorksheet:
            return "The workbook does not contain a readable worksheet."
        case .invalidArchive:
            return "The .xlsx file could not be parsed."
        }
    }
}

struct XLSXParsingService {
    private let mapper = BankColumnAutoMapper()
    private let previewBuilder = ImportPreviewBuilder()

    func preview(fileURL: URL, overrideMapping: ImportColumnMapping? = nil) throws -> ImportPreviewResult {
        let archive = try Archive(url: fileURL, accessMode: .read)
        let sharedStrings = try loadSharedStrings(from: archive)
        let worksheetReferences = try worksheetReferences(in: archive)

        let selectedReference: (name: String?, path: String)
        if let overrideWorksheetName = overrideMapping?.worksheetName,
           let explicitMatch = worksheetReferences.first(where: { $0.name == overrideWorksheetName }) {
            selectedReference = explicitMatch
        } else if let best = try bestWorksheetReference(from: worksheetReferences, archive: archive, sharedStrings: sharedStrings) {
            selectedReference = best
        } else {
            return ImportPreviewResult(
                rows: [],
                invalidRows: [],
                diagnostics: ImportDiagnostics(
                    sourceType: "xlsx",
                    worksheetName: nil,
                    delimiter: nil,
                    headerRowIndex: nil,
                    mappedColumnsDescription: "No supported bank header detected",
                    rawRowCount: 0,
                    validRowCount: 0,
                    invalidRowCount: 0,
                    importableRowCount: 0
                ),
                mapping: nil,
                requiresManualMapping: true,
                duplicateInfo: nil
            )
        }

        let worksheetXML = try readEntry(at: selectedReference.path, from: archive)
        let worksheetRows = extractRelevantRows(
            from: WorksheetXMLParser(sharedStrings: sharedStrings).parse(data: worksheetXML)
        )
        let mapping = resolvedMapping(
            in: worksheetRows,
            worksheetName: selectedReference.name,
            overrideMapping: overrideMapping
        )

        return previewBuilder.buildPreview(
            from: RawImportTable(sourceType: "xlsx", worksheetName: selectedReference.name, delimiter: nil, rows: worksheetRows),
            mapping: mapping,
            requiresManualMapping: overrideMapping != nil || mapping == nil
        )
    }

    private func bestWorksheetReference(
        from references: [(name: String?, path: String)],
        archive: Archive,
        sharedStrings: [String]
    ) throws -> (name: String?, path: String)? {
        var bestReference: (name: String?, path: String)?
        var bestScore = Int.min

        for worksheetReference in references {
            let worksheetXML = try readEntry(at: worksheetReference.path, from: archive)
            let worksheetRows = extractRelevantRows(
                from: WorksheetXMLParser(sharedStrings: sharedStrings).parse(data: worksheetXML)
            )
            let mapping = resolvedMapping(in: worksheetRows, worksheetName: worksheetReference.name, overrideMapping: nil)
            guard let mapping else {
                continue
            }

            let preview = previewBuilder.buildPreview(
                from: RawImportTable(sourceType: "xlsx", worksheetName: worksheetReference.name, delimiter: nil, rows: worksheetRows),
                mapping: mapping,
                requiresManualMapping: false
            )
            let nonEmptyRows = worksheetRows.dropFirst(mapping.headerRowIndex + 1).filter {
                $0.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }.count
            let score = preview.rows.count * 50 + nonEmptyRows * 2 - preview.invalidRows.count
            if score > bestScore {
                bestScore = score
                bestReference = worksheetReference
            }
        }

        return bestReference
    }

    private func worksheetReferences(in archive: Archive) throws -> [(name: String?, path: String)] {
        let workbookData = try readEntry(at: "xl/workbook.xml", from: archive)
        let relationshipsData = try readEntry(at: "xl/_rels/workbook.xml.rels", from: archive)
        let sheetReferences = WorkbookXMLParser().parseSheetReferences(data: workbookData)
        let relationships = WorkbookRelationshipsXMLParser().parse(data: relationshipsData)
        var resolved: [(name: String?, path: String)] = []

        for sheetReference in sheetReferences {
            if let target = relationships[sheetReference.relationshipID] {
                let normalizedTarget = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/\(target.replacingOccurrences(of: "../", with: ""))"
                if normalizedTarget.hasPrefix("xl/worksheets/"), normalizedTarget.hasSuffix(".xml") {
                    resolved.append((sheetReference.name, normalizedTarget))
                }
            }
        }

        for entry in archive {
            let path = entry.path
            if path.hasPrefix("xl/worksheets/"), path.hasSuffix(".xml") {
                resolved.append((nil, path))
            }
        }

        guard !resolved.isEmpty else {
            throw XLSXParsingError.missingWorksheet
        }

        var seen = Set<String>()
        return resolved.filter { seen.insert($0.path).inserted }
    }

    private func loadSharedStrings(from archive: Archive) throws -> [String] {
        guard archive["xl/sharedStrings.xml"] != nil else {
            return []
        }

        let data = try readEntry(at: "xl/sharedStrings.xml", from: archive)
        return SharedStringsXMLParser().parse(data: data)
    }

    private func readEntry(at path: String, from archive: Archive) throws -> Data {
        guard let entry = archive[path] else {
            throw XLSXParsingError.invalidArchive
        }

        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
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

    private func resolvedMapping(
        in rows: [[String]],
        worksheetName: String?,
        overrideMapping: ImportColumnMapping?
    ) -> ImportColumnMapping? {
        if let overrideMapping,
           let candidate = mapper.detectHeaderCandidate(in: rows) {
            return mapper.mapping(
                from: candidate,
                worksheetName: worksheetName,
                overrides: overrideDictionary(from: overrideMapping)
            )
        }

        if let mapping = try? mapper.detectMapping(in: rows, worksheetName: worksheetName) {
            return mapping
        }

        if let candidate = mapper.detectHeaderCandidate(in: rows) {
            return mapper.mapping(from: candidate, worksheetName: worksheetName)
        }

        return nil
    }

    private func extractRelevantRows(from rows: [[String]]) -> [[String]] {
        guard let candidate = mapper.detectHeaderCandidate(in: rows) else {
            return rows
        }

        let startIndex = max(0, candidate.rowIndex)
        let extracted: [[String]] = Array(rows[startIndex...])
        guard let header = extracted.first else { return [] }

        // Keep the detected header and all data rows with at least 2 non-empty cells,
        // avoiding premature truncation from empty spacer rows between months/sections.
        let dataRows = extracted.dropFirst().filter { row in
            let nonEmptyCount = row.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            return nonEmptyCount >= 2
        }

        return [header] + dataRows
    }
}

private struct WorkbookSheetReference {
    let name: String
    let relationshipID: String
}

private final class WorkbookXMLParser: NSObject, XMLParserDelegate {
    private var sheetReferences: [WorkbookSheetReference] = []

    func parseSheetReferences(data: Data) -> [WorkbookSheetReference] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return sheetReferences
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard elementName == "sheet" else { return }
        if let relationshipID = attributeDict["r:id"] ?? attributeDict["id"],
           let name = attributeDict["name"] {
            sheetReferences.append(WorkbookSheetReference(name: name, relationshipID: relationshipID))
        }
    }
}

private final class WorkbookRelationshipsXMLParser: NSObject, XMLParserDelegate {
    private var relationships: [String: String] = [:]

    func parse(data: Data) -> [String: String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return relationships
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard elementName == "Relationship",
              let id = attributeDict["Id"],
              let target = attributeDict["Target"] else {
            return
        }

        relationships[id] = target
    }
}

private final class SharedStringsXMLParser: NSObject, XMLParserDelegate {
    private var strings: [String] = []
    private var currentString = ""
    private var isCollectingText = false

    func parse(data: Data) -> [String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return strings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "si" {
            currentString = ""
        }
        if elementName == "t" {
            isCollectingText = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isCollectingText else { return }
        currentString.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" {
            isCollectingText = false
        }
        if elementName == "si" {
            strings.append(currentString)
        }
    }
}

private final class WorksheetXMLParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private var rows: [[String]] = []
    private var currentRow: [Int: String] = [:]
    private var currentColumnIndex: Int?
    private var currentCellType: String?
    private var currentValue = ""
    private var isCollectingValue = false
    private var currentRowHasCells = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parse(data: Data) -> [[String]] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return rows
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "row":
            currentRow = [:]
            currentRowHasCells = false
        case "c":
            currentColumnIndex = columnIndex(from: attributeDict["r"] ?? "")
            currentCellType = attributeDict["t"]
            currentValue = ""
            currentRowHasCells = true
        case "v", "t":
            isCollectingValue = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isCollectingValue else { return }
        currentValue.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "v", "t":
            isCollectingValue = false
        case "c":
            guard let columnIndex = currentColumnIndex else { return }
            currentRow[columnIndex] = resolvedCellValue(type: currentCellType, rawValue: currentValue)
            currentColumnIndex = nil
            currentCellType = nil
            currentValue = ""
        case "row":
            guard currentRowHasCells, let maxIndex = currentRow.keys.max() else { return }
            let row = (0...maxIndex).map { currentRow[$0] ?? "" }
            rows.append(row)
        default:
            break
        }
    }

    private func resolvedCellValue(type: String?, rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if type == "s", let index = Int(trimmed), sharedStrings.indices.contains(index) {
            return sharedStrings[index]
        }

        if type == "inlineStr" {
            return trimmed
        }

        return trimmed
    }

    private func columnIndex(from reference: String) -> Int? {
        let letters = reference.prefix { $0.isLetter }
        guard !letters.isEmpty else { return nil }

        return letters.reduce(0) { partial, character in
            let scalar = Int(character.uppercased().unicodeScalars.first?.value ?? 65)
            return partial * 26 + (scalar - 64)
        } - 1
    }
}
