import Foundation

enum RecurringExpenseDetectionStatus: String, Equatable {
    case confirmed
    case provisional
}

struct RecurringExpenseDetection: Identifiable, Equatable {
    let id: String
    let concept: String
    let merchantName: String?
    let averageAmount: Decimal
    let occurrences: Int
    let expectedMonths: Int
    let missingMonths: [Date]
    let latestDate: Date
    let transactionIDs: [UUID]
    let monthlyCoverage: Double
    let amountVariation: Double
    let dayVariation: Double
    let confidence: Double
    let status: RecurringExpenseDetectionStatus
    let recurrenceType: RecurrenceType
}

struct RecurringExpenseDetectorConfiguration {
    var minimumDistinctMonths = 3
    var minimumCoverage = 0.67
    var maximumAmountVariation = 0.35
    var maximumDayVariation = 10.0
    var maximumMonthsWithMultipleCharges = 1

    static let `default` = RecurringExpenseDetectorConfiguration()
}

struct RecurringExpenseDetector {
    private let classifier: FinancialMovementClassifier
    private let configuration: RecurringExpenseDetectorConfiguration
    private let calendar: Calendar

    init(
        classifier: FinancialMovementClassifier = FinancialMovementClassifier(),
        configuration: RecurringExpenseDetectorConfiguration = .default,
        calendar: Calendar = .current
    ) {
        self.classifier = classifier
        self.configuration = configuration
        self.calendar = calendar
    }

    func detect(from entries: [FinancialReportingEntry]) -> [RecurringExpenseDetection] {
        let candidates = entries.filter { entry in
            classifier.isExpense(entry.transaction) &&
            entry.transaction.duplicateReviewStatusRaw != DuplicateReviewStatus.pending.rawValue
        }

        return Dictionary(grouping: candidates, by: seriesKey(for:))
            .compactMap { key, items in
                buildDetection(key: key, entries: items)
            }
            .sorted {
                if $0.status != $1.status {
                    return $0.status == .confirmed
                }
                if $0.confidence != $1.confidence {
                    return $0.confidence > $1.confidence
                }
                return $0.averageAmount > $1.averageAmount
            }
    }

    private func buildDetection(
        key: String,
        entries: [FinancialReportingEntry]
    ) -> RecurringExpenseDetection? {
        guard !entries.isEmpty else { return nil }

        let groupedByMonth = Dictionary(grouping: entries) {
            startOfMonth(for: $0.date)
        }
        guard let firstMonth = groupedByMonth.keys.min(),
              let lastMonth = groupedByMonth.keys.max() else {
            return nil
        }

        let expectedMonths = monthDistance(from: firstMonth, to: lastMonth) + 1
        let monthsWithMultipleCharges = groupedByMonth.values.filter { $0.count > 1 }.count
        guard monthsWithMultipleCharges <= configuration.maximumMonthsWithMultipleCharges else {
            return nil
        }

        let monthlyRepresentatives = groupedByMonth.compactMap { _, monthEntries in
            representative(from: monthEntries)
        }
        let occurrences = monthlyRepresentatives.count
        guard occurrences >= configuration.minimumDistinctMonths,
              expectedMonths >= configuration.minimumDistinctMonths else {
            return nil
        }

        let monthlyCoverage = Double(occurrences) / Double(expectedMonths)
        guard monthlyCoverage >= configuration.minimumCoverage else { return nil }

        let amounts = monthlyRepresentatives.map { absolute($0.amount) }
        let typicalAmount = median(amounts)
        guard typicalAmount > .zero else { return nil }

        let amountVariation = maximumRelativeDeviation(of: amounts, from: typicalAmount)
        let days = monthlyRepresentatives.map { Double(calendar.component(.day, from: $0.date)) }
        let typicalDay = median(days)
        let dayVariation = days.map { abs($0 - typicalDay) }.max() ?? 0
        guard amountVariation <= configuration.maximumAmountVariation,
              dayVariation <= configuration.maximumDayVariation else {
            return nil
        }

        let missingMonths = sequenceOfMonths(from: firstMonth, through: lastMonth).filter { month in
            groupedByMonth[month] == nil
        }
        let coverageScore = monthlyCoverage
        let amountScore = max(0, 1 - amountVariation / configuration.maximumAmountVariation)
        let dayScore = max(0, 1 - dayVariation / configuration.maximumDayVariation)
        let confidence = min(1, max(0, coverageScore * 0.5 + amountScore * 0.3 + dayScore * 0.2))
        let status: RecurringExpenseDetectionStatus = confidence >= 0.75 ? .confirmed : .provisional
        let firstEntry = monthlyRepresentatives.sorted { $0.date < $1.date }.first
        let latestDate = monthlyRepresentatives.map(\.date).max() ?? .distantPast

        return RecurringExpenseDetection(
            id: key,
            concept: firstEntry?.transaction.rawDescription ?? key,
            merchantName: firstEntry?.transaction.merchantCanonicalName,
            averageAmount: amounts.reduce(Decimal.zero, +) / Decimal(amounts.count),
            occurrences: occurrences,
            expectedMonths: expectedMonths,
            missingMonths: missingMonths,
            latestDate: latestDate,
            transactionIDs: monthlyRepresentatives.map { $0.transaction.id },
            monthlyCoverage: monthlyCoverage,
            amountVariation: amountVariation,
            dayVariation: dayVariation,
            confidence: confidence,
            status: status,
            recurrenceType: .monthly
        )
    }

    private func representative(from entries: [FinancialReportingEntry]) -> FinancialReportingEntry? {
        guard entries.count > 1 else { return entries.first }
        let typicalAmount = median(entries.map { absolute($0.amount) })
        return entries.min {
            let lhsDistance = absolute(absolute($0.amount) - typicalAmount)
            let rhsDistance = absolute(absolute($1.amount) - typicalAmount)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            return $0.date < $1.date
        }
    }

    private func seriesKey(for entry: FinancialReportingEntry) -> String {
        let merchant = normalizedLabel(entry.transaction.merchantCanonicalName)
        if !merchant.isEmpty && !isGenericLabel(merchant) {
            return merchant
        }

        let description = normalizedLabel(
            entry.transaction.cleanedDescription.isEmpty
                ? entry.transaction.rawDescription
                : entry.transaction.cleanedDescription
        )
        return description
    }

    private func normalizedLabel(_ value: String?) -> String {
        guard let value else { return "" }
        return value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isGenericLabel(_ label: String) -> Bool {
        let words = Set(label.split(separator: " ").map(String.init))
        let genericWords = [
            "TRANSFERENCIA", "TRANSF", "TRASPASO", "BIZUM", "ABONO", "RECIBO", "CARGO",
            "DISPOSICION", "MOVIMIENTO", "INGRESO", "PAGO", "COMPRA", "TARJETA"
        ]
        return genericWords.contains(where: words.contains) ||
            (words.contains("S") && words.contains("ORD"))
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func monthDistance(from start: Date, to end: Date) -> Int {
        calendar.dateComponents([.month], from: start, to: end).month ?? 0
    }

    private func sequenceOfMonths(from start: Date, through end: Date) -> [Date] {
        var months: [Date] = []
        var current = start
        while current <= end {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }
        return months
    }

    private func median(_ values: [Decimal]) -> Decimal {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return .zero }
        if sorted.count.isMultiple(of: 2) {
            let upper = sorted.count / 2
            return (sorted[upper - 1] + sorted[upper]) / Decimal(2)
        }
        return sorted[sorted.count / 2]
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        if sorted.count.isMultiple(of: 2) {
            let upper = sorted.count / 2
            return (sorted[upper - 1] + sorted[upper]) / 2
        }
        return sorted[sorted.count / 2]
    }

    private func maximumRelativeDeviation(of values: [Decimal], from typical: Decimal) -> Double {
        guard typical > .zero else { return 1 }
        return values
            .map { decimalToDouble(absolute($0 - typical) / typical) }
            .max() ?? 0
    }

    private func decimalToDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private func absolute(_ value: Decimal) -> Decimal {
        value < .zero ? -value : value
    }
}
