import Foundation

/// Read-only view of a movement used for transfer pairing, so detection can
/// run off the main actor and be tested without SwiftData.
struct TransferPairCandidate: Sendable, Hashable {
    let id: UUID
    let bookingDate: Date
    let amount: Decimal
    let currencyCode: String
    let accountName: String?
    let importBatchID: UUID?
    let description: String
    let isEligible: Bool

    init(
        id: UUID,
        bookingDate: Date,
        amount: Decimal,
        currencyCode: String = AppConfig.defaultCurrencyCode,
        accountName: String?,
        importBatchID: UUID?,
        description: String,
        isEligible: Bool = true
    ) {
        self.id = id
        self.bookingDate = bookingDate
        self.amount = amount
        self.currencyCode = currencyCode.uppercased()
        let trimmedAccount = accountName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.accountName = (trimmedAccount?.isEmpty ?? true) ? nil : trimmedAccount
        self.importBatchID = importBatchID
        self.description = description
        self.isEligible = isEligible
    }

    /// Movements already marked as transfer or adjustment, or decided by the
    /// user, are never proposed again.
    init(_ transaction: Transaction) {
        let kind = transaction.resolvedKind
        self.init(
            id: transaction.id,
            bookingDate: transaction.bookingDate,
            amount: transaction.amount,
            currencyCode: transaction.currencyCode,
            accountName: transaction.accountName,
            importBatchID: transaction.importBatchID,
            description: transaction.rawDescription,
            isEligible: kind != .transfer &&
                kind != .adjustment &&
                transaction.categorizationSourceRaw != CategorizationSource.manual.rawValue
        )
    }
}

struct TransferPairProposal: Identifiable, Sendable, Hashable {
    /// Stable for the same two movements, used for session dismissals.
    let id: String
    let outgoing: TransferPairCandidate
    let incoming: TransferPairCandidate
    let confidence: Double
    /// True when both movements carry an account name (stronger evidence).
    let hasNamedAccounts: Bool

    var amount: Decimal { incoming.amount }
    var dayGap: Int { TransferPairDetector.calendarDayGap(outgoing.bookingDate, incoming.bookingDate) }

    static func key(_ first: UUID, _ second: UUID) -> String {
        [first.uuidString, second.uuidString].sorted().joined(separator: "|")
    }
}

/// Finds an outgoing and an incoming movement of the same absolute amount in
/// different accounts within a few days. Conservative by design (ADR 0002):
/// a movement with more than one possible counterpart is never proposed.
struct TransferPairDetector: Sendable {
    static let maxDayGap = 3
    private static let transferSignals = [
        "TRANSFER", "TRASPASO", "TRASPAS", "BIZUM", "ENVIO", "ENVÍO", "RECIBIDA", "EMITIDA", "ORDENANTE", "BENEFICIARIO"
    ]

    func detect(in candidates: [TransferPairCandidate]) -> [TransferPairProposal] {
        let eligible = candidates.filter { $0.isEligible && $0.amount != .zero }
        // A transfer keeps currency and amount; anything else is not the same money.
        let byAmount = Dictionary(grouping: eligible) { AmountKey(amount: abs($0.amount), currencyCode: $0.currencyCode) }

        var edges: [(TransferPairCandidate, TransferPairCandidate)] = []
        var degree: [UUID: Int] = [:]

        for (_, group) in byAmount {
            let outgoing = group.filter { $0.amount < .zero }
            let incoming = group.filter { $0.amount > .zero }
            guard !outgoing.isEmpty, !incoming.isEmpty else { continue }

            for out in outgoing {
                for inc in incoming where Self.isPlausiblePair(out, inc) {
                    edges.append((out, inc))
                    degree[out.id, default: 0] += 1
                    degree[inc.id, default: 0] += 1
                }
            }
        }

        return edges
            .filter { degree[$0.0.id] == 1 && degree[$0.1.id] == 1 }
            .map { out, inc in
                let named = out.accountName != nil && inc.accountName != nil
                return TransferPairProposal(
                    id: TransferPairProposal.key(out.id, inc.id),
                    outgoing: out,
                    incoming: inc,
                    confidence: Self.confidence(out, inc, namedAccounts: named),
                    hasNamedAccounts: named
                )
            }
            .sorted { lhs, rhs in
                if lhs.incoming.bookingDate != rhs.incoming.bookingDate {
                    return lhs.incoming.bookingDate > rhs.incoming.bookingDate
                }
                return lhs.id < rhs.id
            }
    }

    private struct AmountKey: Hashable {
        let amount: Decimal
        let currencyCode: String
    }

    /// Whole calendar days between two bookings, so a daylight-saving change
    /// never widens or narrows the window.
    static func calendarDayGap(_ first: Date, _ second: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: first)
        let end = calendar.startOfDay(for: second)
        return abs(calendar.dateComponents([.day], from: start, to: end).day ?? Int.max)
    }

    private static func isPlausiblePair(_ out: TransferPairCandidate, _ inc: TransferPairCandidate) -> Bool {
        guard calendarDayGap(out.bookingDate, inc.bookingDate) <= maxDayGap else { return false }

        // Same text on both sides is a purchase and its refund, not a transfer.
        if normalized(out.description) == normalized(inc.description) {
            return false
        }

        switch (out.accountName, inc.accountName) {
        case let (outAccount?, incAccount?):
            return outAccount.caseInsensitiveCompare(incAccount) != .orderedSame
        default:
            // Without account names we cannot rule out the same account, so
            // require different imports and an explicit transfer keyword.
            guard let outBatch = out.importBatchID, let incBatch = inc.importBatchID, outBatch != incBatch else {
                return false
            }
            return hasTransferSignal(out.description + " " + inc.description)
        }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func hasTransferSignal(_ text: String) -> Bool {
        let upper = text.uppercased()
        return transferSignals.contains(where: upper.contains)
    }

    private static func confidence(_ out: TransferPairCandidate, _ inc: TransferPairCandidate, namedAccounts: Bool) -> Double {
        var score = namedAccounts ? 0.6 : 0.45
        if hasTransferSignal(out.description + " " + inc.description) {
            score += 0.2
        }
        if calendarDayGap(out.bookingDate, inc.bookingDate) == 0 {
            score += 0.1
        }
        return min(score, 0.95)
    }
}
