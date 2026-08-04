import Foundation

enum DuplicateMovementMatchKind: Equatable {
    case exactFingerprint
    case crossSourceEvidence
}

struct DuplicateMovementMatch {
    let existingID: UUID
    let kind: DuplicateMovementMatchKind
    let score: Double
}

struct DuplicateMovementPair: Identifiable {
    let firstID: UUID
    let secondID: UUID
    let kind: DuplicateMovementMatchKind
    let score: Double

    var id: String {
        [firstID.uuidString, secondID.uuidString].sorted().joined(separator: "|")
    }
}

/// A bank-independent representation used only while deciding whether an
/// imported row was already persisted.
struct DuplicateMovementCandidate {
    let id: UUID
    let bookingDate: Date
    let valueDate: Date?
    let cleanedDescription: String
    let merchantCanonicalName: String?
    let amount: Decimal
    let currencyCode: String
    let direction: Int
    let fingerprint: String
    let importBatchID: UUID?

    init(id: UUID = UUID(), normalized: NormalizedTransactionDTO) {
        self.id = id
        self.bookingDate = normalized.bookingDate
        self.valueDate = normalized.valueDate
        self.cleanedDescription = normalized.cleanedDescription
        self.merchantCanonicalName = normalized.merchantCanonicalName
        self.amount = normalized.amount
        self.currencyCode = normalized.currencyCode
        self.direction = normalized.sign
        self.fingerprint = normalized.fingerprint
        self.importBatchID = nil
    }

    init(normalized: NormalizedTransactionDTO, importBatchID: UUID?) {
        self.id = UUID()
        self.bookingDate = normalized.bookingDate
        self.valueDate = normalized.valueDate
        self.cleanedDescription = normalized.cleanedDescription
        self.merchantCanonicalName = normalized.merchantCanonicalName
        self.amount = normalized.amount
        self.currencyCode = normalized.currencyCode
        self.direction = normalized.sign
        self.fingerprint = normalized.fingerprint
        self.importBatchID = importBatchID
    }

    init(transaction: Transaction) {
        self.id = transaction.id
        self.bookingDate = transaction.bookingDate
        self.valueDate = transaction.valueDate
        self.cleanedDescription = transaction.cleanedDescription
        self.merchantCanonicalName = transaction.merchantCanonicalName
        self.amount = transaction.amount
        self.currencyCode = transaction.currencyCode
        self.direction = transaction.amount >= .zero ? 1 : -1
        self.fingerprint = transaction.fingerprint
        self.importBatchID = transaction.importBatchID
    }
}

struct DuplicateMovementDetector {
    struct Configuration {
        let maximumDateDistanceInDays: Int

        init(maximumDateDistanceInDays: Int = 1) {
            self.maximumDateDistanceInDays = max(0, maximumDateDistanceInDays)
        }
    }

    private let configuration: Configuration
    private let calendar: Calendar

    init(configuration: Configuration = Configuration(), calendar: Calendar = .current) {
        self.configuration = configuration
        self.calendar = calendar
    }

    /// Matches rows one-to-one so repeated legitimate transactions are kept.
    func findMatches(
        for candidates: [DuplicateMovementCandidate],
        against existing: [DuplicateMovementCandidate]
    ) -> [UUID: DuplicateMovementMatch] {
        var consumedExistingIDs: Set<UUID> = []
        var matches: [UUID: DuplicateMovementMatch] = [:]

        for candidate in candidates {
            guard let match = findMatch(
                for: candidate,
                against: existing,
                excluding: consumedExistingIDs
            ) else {
                continue
            }

            consumedExistingIDs.insert(match.existingID)
            matches[candidate.id] = match
        }

        return matches
    }

    func findPotentialDuplicatePairs(in candidates: [DuplicateMovementCandidate]) -> [DuplicateMovementPair] {
        guard candidates.count > 1 else { return [] }

        var pairs: [DuplicateMovementPair] = []
        var emittedPairIDs: Set<String> = []

        // Fingerprints are authoritative and can be indexed directly. This
        // keeps an audit of a large database linear for the common exact case.
        let exactGroups = Dictionary(
            grouping: candidates.filter { !$0.fingerprint.isEmpty },
            by: { $0.fingerprint }
        )
        for group in exactGroups.values where group.count > 1 {
            appendPairs(
                from: group,
                to: &pairs,
                emittedPairIDs: &emittedPairIDs,
                score: { _, _ in (.exactFingerprint, 1.0) }
            )
        }

        // Fuzzy matching only makes sense for the same signed amount and
        // currency. Bucketing avoids comparing every historical transaction
        // with every other transaction before the date/name checks run.
        let fuzzyGroups = Dictionary(grouping: candidates) { candidate in
            FuzzyBucketKey(
                currencyCode: candidate.currencyCode,
                amount: candidate.amount,
                direction: candidate.direction
            )
        }
        for group in fuzzyGroups.values where group.count > 1 {
            appendPairs(
                from: group,
                to: &pairs,
                emittedPairIDs: &emittedPairIDs
            ) { first, second in
                score(candidate: first, existing: second)
            }
        }

        return pairs.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.id < rhs.id
            }
            return lhs.score > rhs.score
        }
    }

    private func appendPairs(
        from candidates: [DuplicateMovementCandidate],
        to pairs: inout [DuplicateMovementPair],
        emittedPairIDs: inout Set<String>,
        score: (DuplicateMovementCandidate, DuplicateMovementCandidate) -> (kind: DuplicateMovementMatchKind, score: Double)?
    ) {
        guard candidates.count > 1 else { return }

        for firstIndex in candidates.indices {
            for secondIndex in candidates.indices where secondIndex > firstIndex {
                let first = candidates[firstIndex]
                let second = candidates[secondIndex]

                if let firstBatchID = first.importBatchID,
                   firstBatchID == second.importBatchID {
                    continue
                }

                let pairID = [first.id.uuidString, second.id.uuidString].sorted().joined(separator: "|")
                guard emittedPairIDs.insert(pairID).inserted,
                      let scoredMatch = score(first, second) else {
                    continue
                }

                pairs.append(
                    DuplicateMovementPair(
                        firstID: first.id,
                        secondID: second.id,
                        kind: scoredMatch.kind,
                        score: scoredMatch.score
                    )
                )
            }
        }
    }

    private func findMatch(
        for candidate: DuplicateMovementCandidate,
        against existing: [DuplicateMovementCandidate],
        excluding consumedExistingIDs: Set<UUID>
    ) -> DuplicateMovementMatch? {
        existing
            .filter { !consumedExistingIDs.contains($0.id) }
            .compactMap { existingCandidate in
                score(candidate: candidate, existing: existingCandidate)
                    .map { scoredMatch in
                        (existingCandidate.id, scoredMatch)
                    }
            }
            .sorted { lhs, rhs in
                if lhs.1.score == rhs.1.score {
                    return lhs.0.uuidString < rhs.0.uuidString
                }
                return lhs.1.score > rhs.1.score
            }
            .first
            .map { existingID, scoredMatch in
                DuplicateMovementMatch(
                    existingID: existingID,
                    kind: scoredMatch.kind,
                    score: scoredMatch.score
                )
            }
    }

    private func score(
        candidate: DuplicateMovementCandidate,
        existing: DuplicateMovementCandidate
    ) -> (kind: DuplicateMovementMatchKind, score: Double)? {
        // Keep the original exact-fingerprint behavior authoritative. It also
        // preserves compatibility with transactions edited after import whose
        // stored fingerprint still represents the source row.
        if !candidate.fingerprint.isEmpty,
           candidate.fingerprint == existing.fingerprint {
            return (.exactFingerprint, 1.0)
        }

        guard candidate.currencyCode.caseInsensitiveCompare(existing.currencyCode) == .orderedSame,
              candidate.amount == existing.amount,
              candidate.direction == existing.direction,
              let dateDistance = minimumDateDistance(between: candidate, and: existing),
              dateDistance <= configuration.maximumDateDistanceInDays else {
            return nil
        }

        guard let descriptionScore = descriptionEvidenceScore(candidate: candidate, existing: existing) else {
            return nil
        }

        let datePenalty = Double(dateDistance) * 0.05
        return (.crossSourceEvidence, max(0, descriptionScore - datePenalty))
    }

    private func minimumDateDistance(
        between candidate: DuplicateMovementCandidate,
        and existing: DuplicateMovementCandidate
    ) -> Int? {
        let candidateDates = [candidate.bookingDate, candidate.valueDate].compactMap { $0 }
        let existingDates = [existing.bookingDate, existing.valueDate].compactMap { $0 }

        guard !candidateDates.isEmpty, !existingDates.isEmpty else { return nil }

        return candidateDates
            .flatMap { candidateDate in
                existingDates.map { existingDate in
                    calendar.dateComponents(
                        [.day],
                        from: calendar.startOfDay(for: candidateDate),
                        to: calendar.startOfDay(for: existingDate)
                    ).day.map(abs)
                }
            }
            .compactMap { $0 }
            .min()
    }

    private func descriptionEvidenceScore(
        candidate: DuplicateMovementCandidate,
        existing: DuplicateMovementCandidate
    ) -> Double? {
        if let candidateMerchant = meaningfulNormalizedName(candidate.merchantCanonicalName),
           let existingMerchant = meaningfulNormalizedName(existing.merchantCanonicalName),
           candidateMerchant == existingMerchant {
            return 0.98
        }

        let candidateTokens = meaningfulTokens(in: candidate.cleanedDescription)
        let existingTokens = meaningfulTokens(in: existing.cleanedDescription)
        let sharedTokens = candidateTokens.intersection(existingTokens)

        guard !sharedTokens.isEmpty else { return nil }

        let smallestDescription = max(1, min(candidateTokens.count, existingTokens.count))
        let overlap = Double(sharedTokens.count) / Double(smallestDescription)

        // One shared meaningful token is enough for a merchant such as DIA or AXA,
        // but generic banking words alone must never produce a match.
        guard sharedTokens.count >= 2 || overlap >= 0.5 else { return nil }

        return min(0.94, 0.70 + overlap * 0.24)
    }

    private func meaningfulNormalizedName(_ name: String?) -> String? {
        guard let name else { return nil }
        let normalized = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty,
              !meaninglessTokens.contains(normalized) else {
            return nil
        }

        return normalized
    }

    private func meaningfulTokens(in text: String) -> Set<String> {
        let normalized = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "[^A-Z0-9]+", with: " ", options: .regularExpression)

        return Set(
            normalized
                .split(separator: " ")
                .map(String.init)
                .filter { token in
                    token.count >= 3 && !meaninglessTokens.contains(token)
                }
        )
    }

    private let meaninglessTokens: Set<String> = [
        "AUT",
        "BANCARIO",
        "BANCARIA",
        "CARD",
        "COMPRA",
        "CON",
        "DE",
        "DEL",
        "DOMICILIACION",
        "ENTRADA",
        "IMPORTE",
        "MOVIMIENTO",
        "OPERACION",
        "ORD",
        "PAGO",
        "POS",
        "RECIBO",
        "SEPA",
        "S",
        "TARJ",
        "TARJETA",
        "TRASPASO",
        "TRANSFERENCIA",
        "VISA"
    ]
}

private struct FuzzyBucketKey: Hashable {
    let currencyCode: String
    let amount: String
    let direction: Int

    init(currencyCode: String, amount: Decimal, direction: Int) {
        self.currencyCode = currencyCode.uppercased()
        self.amount = NSDecimalNumber(decimal: amount).stringValue
        self.direction = direction
    }
}
