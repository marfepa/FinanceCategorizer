import Foundation

enum BankColumnAutoMapperError: LocalizedError {
    case headerNotFound
    case missingRequiredColumns

    var errorDescription: String? {
        switch self {
        case .headerNotFound:
            return "The importer could not find a supported bank header row."
        case .missingRequiredColumns:
            return "The file is missing required columns for date and amount."
        }
    }
}

struct BankColumnAutoMapper {
    func detectMapping(in rows: [[String]], worksheetName: String? = nil) throws -> ImportColumnMapping {
        guard let headerCandidate = detectHeaderCandidate(in: rows) else {
            throw BankColumnAutoMapperError.headerNotFound
        }

        let normalized = headerCandidate.normalizedHeaders
        let bookingDateIndex = firstIndex(in: normalized) { header in
            header == "fecha" ||
            header == "date" ||
            header.contains("fecha operacion") ||
            header.contains("fecha apunte") ||
            (header.contains("fecha") && (
                header.contains("cble") ||
                header.contains("ctable") ||
                header.contains("contable") ||
                header.contains("ctble")
            ))
        }
        let valueDateIndex = firstIndex(in: normalized) { header in
            header.contains("fecha valor") ||
            header == "f valor" ||
            header == "fvalor" ||
            header == "valor" ||
            header == "value date"
        }
        let conceptIndex = firstIndex(in: normalized) { header in
            header == "concepto" ||
            header == "descripcion" ||
            header == "descripción" ||
            header == "description" ||
            header == "concept"
        }
        let extendedConceptIndex = firstIndex(in: normalized) { header in
            header.contains("concepto ampliado") ||
            header.contains("descripcion ampliada") ||
            header.contains("descripción ampliada") ||
            header == "detalle" ||
            header == "memo"
        }
        let amountIndex = firstIndex(in: normalized) { header in
            header.contains("importe") ||
            header == "amount" ||
            header == "cargo abono" ||
            header == "valor importe"
        }
        let balanceIndex = firstIndex(in: normalized) { header in
            header.contains("saldo") || header == "balance"
        }
        let currencyIndex = firstIndex(in: normalized) { header in
            header.contains("moneda") || header == "currency"
        }

        let mapping = ImportColumnMapping(
            worksheetName: worksheetName,
            headerRowIndex: headerCandidate.rowIndex,
            availableHeaders: headerCandidate.headers,
            bookingDateIndex: bookingDateIndex,
            valueDateIndex: valueDateIndex,
            conceptIndex: conceptIndex,
            extendedConceptIndex: extendedConceptIndex,
            amountIndex: amountIndex,
            balanceIndex: balanceIndex,
            currencyIndex: currencyIndex
        )

        guard mapping.hasReliableAutomaticMapping else {
            throw BankColumnAutoMapperError.missingRequiredColumns
        }

        return mapping
    }

    func detectHeaderCandidate(in rows: [[String]]) -> (rowIndex: Int, headers: [String], normalizedHeaders: [String], score: Int)? {
        let candidates = rows.prefix(30).enumerated().compactMap { rowIndex, row -> (Int, [String], [String], Int)? in
            let nonEmptyCells = row.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard nonEmptyCells.count >= 3 else {
                return nil
            }

            let normalized = row.map(normalizeHeader)
            let score = headerScore(for: normalized)
            guard score >= 4, rowLooksLikeHeader(normalized) else {
                return nil
            }
            return (rowIndex, row, normalized, score)
        }

        return candidates.max { lhs, rhs in
            if lhs.3 == rhs.3 {
                return lhs.0 > rhs.0
            }
            return lhs.3 < rhs.3
        }
    }

    func mapping(from candidate: (rowIndex: Int, headers: [String], normalizedHeaders: [String], score: Int), worksheetName: String? = nil, overrides: [ImportColumnField: Int?] = [:]) -> ImportColumnMapping {
        var mapping = ImportColumnMapping(
            worksheetName: worksheetName,
            headerRowIndex: candidate.rowIndex,
            availableHeaders: candidate.headers,
            bookingDateIndex: firstIndex(in: candidate.normalizedHeaders) { $0 == "fecha" || $0 == "date" || $0.contains("fecha") && ($0.contains("cble") || $0.contains("ctble") || $0.contains("contable")) },
            valueDateIndex: firstIndex(in: candidate.normalizedHeaders) { $0.contains("fecha valor") || $0 == "f valor" || $0 == "fvalor" || $0 == "valor" || $0 == "value date" },
            conceptIndex: firstIndex(in: candidate.normalizedHeaders) { $0 == "concepto" || $0.contains("descripcion") || $0 == "concept" },
            extendedConceptIndex: firstIndex(in: candidate.normalizedHeaders) { $0.contains("concepto ampliado") || $0.contains("descripcion ampliada") || $0 == "detalle" || $0 == "memo" },
            amountIndex: firstIndex(in: candidate.normalizedHeaders) { $0.contains("importe") || $0 == "amount" || $0 == "cargo abono" || $0 == "valor importe" },
            balanceIndex: firstIndex(in: candidate.normalizedHeaders) { $0.contains("saldo") || $0 == "balance" },
            currencyIndex: firstIndex(in: candidate.normalizedHeaders) { $0.contains("moneda") || $0 == "currency" }
        )

        for (field, index) in overrides {
            mapping = mapping.updating(field, index: index)
        }

        return mapping
    }

    private func firstIndex(in headers: [String], matching predicate: (String) -> Bool) -> Int? {
        headers.firstIndex(where: predicate)
    }

    private func headerScore(for headers: [String]) -> Int {
        headers.reduce(0) { partial, header in
            if header == "fecha" || header == "date" || header.contains("fecha valor") || header.contains("fecha operacion") || header.contains("fecha apunte") || header.contains("fecha cble") || header.contains("fecha contable") {
                return partial + 3
            }
            if header.contains("importe") || header == "amount" || header == "cargo abono" || header == "valor importe" {
                return partial + 4
            }
            if header == "concepto" || header.contains("concepto ampliado") || header.contains("descripcion") || header == "description" || header == "concept" || header == "detalle" {
                return partial + 3
            }
            if header.contains("saldo") || header == "balance" { return partial + 2 }
            if header.contains("moneda") || header == "currency" { return partial + 2 }
            return partial
        }
    }

    private func rowLooksLikeHeader(_ headers: [String]) -> Bool {
        let nonEmptyHeaders = headers.filter { !$0.isEmpty }
        let alphabeticCells = nonEmptyHeaders.filter { $0.rangeOfCharacter(from: .letters) != nil }
        let digitHeavyCells = nonEmptyHeaders.filter { header in
            let digits = header.filter(\.isNumber).count
            return digits >= max(4, header.count / 2)
        }

        return alphabeticCells.count >= 2 && digitHeavyCells.count <= 1
    }

    private func normalizeHeader(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
