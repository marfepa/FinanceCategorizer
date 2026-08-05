import Foundation

struct OpenbankPDFStrategy: PDFBankStrategy {
    var bankName: String { "Openbank" }
    
    // MARK: - Regex Patterns

    private let dateStartRegex: NSRegularExpression?
    private let spanishAmountRegex: NSRegularExpression?

    init() {
        dateStartRegex = try? NSRegularExpression(pattern: #"^(\d{2}[/-]\d{2}[/-]\d{4})\b"#)
        spanishAmountRegex = try? NSRegularExpression(pattern: #"[-+−]?\s*\d{1,3}(?:[.\s]\d{3})*,\d{2}(?=\s*(?:EUR|€)?(?:\s|$))"#)
    }
    
    func matches(fullText: String) -> Double {
        let textMatch = fullText.lowercased()
        if textMatch.contains("openbank") || textMatch.contains("open bank") {
            return 1.0 // Matches perfectly
        }
        return 0.0
    }
    
    private func lineStartsWithDate(_ line: String) -> Bool {
        guard let dateStartRegex else { return false }
        let range = NSRange(location: 0, length: line.utf16.count)
        return dateStartRegex.firstMatch(in: line, range: range) != nil
    }

    // MARK: - Block-Based Extraction

    func extractTransactions(from rawLines: [String]) -> [RawPDFTransaction] {
        let trimmedLines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var transactions: [RawPDFTransaction] = []
        var pendingBlock: [String] = []

        for line in trimmedLines {
            let startsWithDate = lineStartsWithDate(line)
            if startsWithDate && !pendingBlock.isEmpty {
                if let tx = buildTransaction(from: pendingBlock) {
                    transactions.append(tx)
                }
                pendingBlock = []
            }

            if startsWithDate || !pendingBlock.isEmpty {
                pendingBlock.append(line)
            }
        }

        if !pendingBlock.isEmpty {
            if let tx = buildTransaction(from: pendingBlock) {
                transactions.append(tx)
            }
        }

        return transactions
    }

    private func buildTransaction(from lines: [String]) -> RawPDFTransaction? {
        guard !lines.isEmpty, let dateStartRegex else { return nil }

        var allDates: [String] = []
        var allAmounts: [String] = []
        var conceptParts: [String] = []
        let rawText = lines.joined(separator: " ")

        for line in lines {
            var remaining = line

            while true {
                let r = NSRange(location: 0, length: remaining.utf16.count)
                guard let m = dateStartRegex.firstMatch(in: remaining, range: r),
                      m.range.location == 0 else { break }
                let dateStr = (remaining as NSString).substring(with: m.range)
                allDates.append(dateStr)
                remaining = String(remaining.dropFirst(m.range.length))
                    .trimmingCharacters(in: .whitespaces)
            }

            let (text, lineAmounts) = separateTrailingAmounts(from: remaining)
            allAmounts.append(contentsOf: lineAmounts)

            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanText.isEmpty && !isNoiseLine(cleanText) {
                conceptParts.append(cleanText)
            }
        }

        guard !allDates.isEmpty, !allAmounts.isEmpty else { return nil }

        let dateStr = allDates[0]
        let valueDateStr = allDates.count >= 2 ? allDates[1] : nil

        let amountStr: String
        let balanceStr: String?
        if allAmounts.count >= 2 {
            amountStr = allAmounts[allAmounts.count - 2]
            balanceStr = allAmounts[allAmounts.count - 1]
        } else {
            amountStr = allAmounts[0]
            balanceStr = nil
        }

        let concept = conceptParts
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return RawPDFTransaction(
            dateStr: dateStr,
            valueDateStr: valueDateStr,
            concept: concept,
            amountStr: amountStr,
            balanceStr: balanceStr,
            rawText: rawText
        )
    }

    private func separateTrailingAmounts(from text: String) -> (String, [String]) {
        guard let spanishAmountRegex else { return (text, []) }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = spanishAmountRegex.matches(in: text, range: fullRange)

        guard !matches.isEmpty else { return (text, []) }

        var trailingStartIndex = matches.count - 1
        for i in stride(from: matches.count - 1, through: 1, by: -1) {
            let prevEnd = matches[i - 1].range.location + matches[i - 1].range.length
            let currStart = matches[i].range.location
            let gap = nsText.substring(with: NSRange(location: prevEnd, length: currStart - prevEnd))
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if gap.isEmpty {
                trailingStartIndex = i - 1
            } else {
                break
            }
        }

        let lastMatch = matches.last!
        let afterLast = nsText.substring(from: lastMatch.range.location + lastMatch.range.length)
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard afterLast.isEmpty else {
            return (text, [])
        }

        let trailingMatches = Array(matches[trailingStartIndex...])
        let amounts = trailingMatches.map {
            nsText.substring(with: $0.range)
                .replacingOccurrences(of: "−", with: "-")
                .replacingOccurrences(of: " ", with: "")
        }

        let cutoffLocation = trailingMatches[0].range.location
        let cleanText = nsText.substring(to: cutoffLocation)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (cleanText, amounts)
    }

    private func isNoiseLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if lowered.range(of: #"^p[áa]gina\s+\d+"#, options: .regularExpression) != nil { return true }
        if lowered.range(of: #"^\d+\s*(de|/)\s*\d+$"#, options: .regularExpression) != nil { return true }
        if lowered.range(of: #"^\d{1,4}$"#, options: .regularExpression) != nil { return true }

        let noiseStrings = [
            "fecha", "fecha contable", "fecha valor", "concepto", "importe",
            "saldo", "movimiento", "descripción", "descripcion",
            "f. contable", "f. valor", "debe", "haber",
            "cuenta", "iban", "titular", "extracto", "periodo",
            "openbank", "open bank", "grupo santander",
            "detalle de movimientos", "listado de movimientos",
            "total", "saldo anterior", "saldo final", "saldo disponible",
            "euros", "eur", "€", "moneda", "divisa", "nº cuenta",
            "fecha operación", "fecha operacion"
        ]
        for noise in noiseStrings {
            if lowered == noise { return true }
        }

        if line.count <= 2 { return true }

        return false
    }
}
