import Foundation

struct DuplicateMovementGroup: Identifiable {
    let id: String
    let transactionIDs: [UUID]
    let confidence: Double
    let reasonKey: String
    let recommendedKeepID: UUID
}

struct DuplicateAuditService {
    private let detector: DuplicateMovementDetector

    init(detector: DuplicateMovementDetector = DuplicateMovementDetector()) {
        self.detector = detector
    }

    func analyze(transactions: [Transaction]) -> [DuplicateMovementGroup] {
        guard transactions.count > 1 else { return [] }

        let candidates = transactions.map(DuplicateMovementCandidate.init(transaction:))
        let pairs = detector.findPotentialDuplicatePairs(in: candidates)
        guard !pairs.isEmpty else { return [] }

        var components = DisjointSet(ids: candidates.map(\.id))
        for pair in pairs {
            components.union(pair.firstID, pair.secondID)
        }

        let transactionsByID = Dictionary(uniqueKeysWithValues: transactions.map { ($0.id, $0) })
        let pairsByComponent = Dictionary(grouping: pairs) { pair in
            components.root(for: pair.firstID)
        }

        return pairsByComponent.compactMap { _, componentPairs in
            let transactionIDs = Set(
                componentPairs.flatMap { [$0.firstID, $0.secondID] }
            ).sorted { $0.uuidString < $1.uuidString }

            let members = transactionIDs.compactMap { transactionsByID[$0] }
            guard members.count >= 2 else { return nil }

            let confidence = componentPairs.map(\.score).min() ?? 0
            let reasonKey = componentPairs.contains(where: { $0.kind == .crossSourceEvidence })
                ? "duplicate.reason.crossSource"
                : "duplicate.reason.exactFingerprint"
            let recommendedKeepID = recommendedKeepID(from: members)
            let groupID = transactionIDs.map(\.uuidString).joined(separator: "|")

            return DuplicateMovementGroup(
                id: groupID,
                transactionIDs: transactionIDs,
                confidence: confidence,
                reasonKey: reasonKey,
                recommendedKeepID: recommendedKeepID
            )
        }
        .sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence {
                return lhs.id < rhs.id
            }
            return lhs.confidence > rhs.confidence
        }
    }

    private func recommendedKeepID(from transactions: [Transaction]) -> UUID {
        transactions
            .sorted { lhs, rhs in
                let lhsScore = keepScore(for: lhs)
                let rhsScore = keepScore(for: rhs)
                if lhsScore == rhsScore {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhsScore > rhsScore
            }
            .first!
            .id
    }

    private func keepScore(for transaction: Transaction) -> Int {
        var score = 0
        if transaction.categoryID != nil { score += 4 }
        if transaction.categorizationSourceRaw == CategorizationSource.manual.rawValue { score += 4 }
        if transaction.valueDate != nil { score += 1 }
        if transaction.externalID != nil { score += 1 }
        score += min(transaction.rawDescription.count, 80) / 20
        return score
    }
}

private struct DisjointSet {
    private var parent: [UUID: UUID]

    init(ids: [UUID]) {
        parent = Dictionary(uniqueKeysWithValues: ids.map { ($0, $0) })
    }

    mutating func union(_ first: UUID, _ second: UUID) {
        let firstRoot = root(for: first)
        let secondRoot = root(for: second)
        guard firstRoot != secondRoot else { return }
        parent[secondRoot] = firstRoot
    }

    func root(for id: UUID) -> UUID {
        var current = id
        while let next = parent[current], next != current {
            current = next
        }
        return current
    }
}
