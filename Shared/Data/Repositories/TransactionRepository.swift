import Foundation
import SwiftData

@MainActor
final class TransactionRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func insert(_ transaction: Transaction) throws {
        let context = makeContext()
        context.insert(transaction)
        try context.save()
    }

    func insert(_ transactions: [Transaction]) throws {
        guard !transactions.isEmpty else { return }
        let context = makeContext()
        for transaction in transactions {
            context.insert(transaction)
        }
        try context.save()
    }

    func fetchAll() throws -> [Transaction] {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.bookingDate, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func count() throws -> Int {
        try fetchAll().count
    }

    func fetch(transactionID: UUID) throws -> Transaction? {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == transactionID })
        return try context.fetch(descriptor).first
    }

    func exists(fingerprint: String) throws -> Bool {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.fingerprint == fingerprint })
        return try !context.fetch(descriptor).isEmpty
    }

    func fetchFingerprintCounts() throws -> [String: Int] {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)
        var counts: [String: Int] = [:]
        for t in transactions {
            counts[t.fingerprint, default: 0] += 1
        }
        return counts
    }

    func fetchFirst(byFingerprint fingerprint: String, sign: Int? = nil) throws -> Transaction? {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.fingerprint == fingerprint && $0.categoryID != nil }
        )
        let transactions = try context.fetch(descriptor)
        guard let sign else { return transactions.first }
        return transactions.first {
            sign >= 0 ? $0.amount > .zero : $0.amount < .zero
        }
    }

    func fetchPendingReview() throws -> [Transaction] {
        try fetchAll()
            .filter {
                $0.resolvedKind != .transfer &&
                ($0.needsReview || $0.categoryID == nil || $0.reviewStatusRaw == ReviewStatus.pending.rawValue)
            }
            .sorted {
                if $0.confidence == $1.confidence {
                    return $0.bookingDate > $1.bookingDate
                }
                return $0.confidence < $1.confidence
            }
    }

    func fetchByMerchant(_ merchant: String, limit: Int = 20) throws -> [Transaction] {
        try fetchAll()
            .filter { ($0.merchantCanonicalName ?? "").caseInsensitiveCompare(merchant) == .orderedSame }
            .prefix(limit)
            .map { $0 }
    }

    func findSimilarTransactions(description: String, amount: Decimal, limit: Int = 5) throws -> [Transaction] {
        let normalizedDescription = description.lowercased()
        return try fetchAll()
            .filter {
                $0.cleanedDescription.contains(normalizedDescription) ||
                normalizedDescription.contains($0.cleanedDescription)
            }
            .sorted {
                let lhsDistance = abs(NSDecimalNumber(decimal: $0.amount - amount).doubleValue)
                let rhsDistance = abs(NSDecimalNumber(decimal: $1.amount - amount).doubleValue)
                return lhsDistance < rhsDistance
            }
            .prefix(limit)
            .map { $0 }
    }

    func applyDecision(
        transactionID: UUID,
        categoryID: UUID?,
        subcategoryID: UUID? = nil,
        source: CategorizationSource,
        confidence: Double,
        needsReview: Bool,
        reviewStatus: ReviewStatus,
        reason: String?,
        isRecurringCandidate: Bool
    ) throws {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == transactionID })
        guard let transaction = try context.fetch(descriptor).first else {
            return
        }

        transaction.categoryID = categoryID
        transaction.subcategoryID = subcategoryID
        transaction.categorizationSourceRaw = source.rawValue
        transaction.confidence = confidence
        transaction.needsReview = needsReview
        transaction.reviewStatusRaw = reviewStatus.rawValue
        transaction.categorizationReason = reason
        transaction.isRecurringCandidate = isRecurringCandidate
        transaction.updatedAt = .now
        try context.save()
    }

    func updateTransactionKind(transactionID: UUID, kind: TransactionKind) throws {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == transactionID })
        guard let transaction = try context.fetch(descriptor).first else {
            return
        }

        let absoluteAmount = abs(NSDecimalNumber(decimal: transaction.amount).doubleValue)
        let signedAmount: Decimal
        switch kind {
        case .income:
            signedAmount = Decimal(absoluteAmount)
        case .expense:
            signedAmount = Decimal(-absoluteAmount)
        case .transfer, .adjustment:
            signedAmount = transaction.amount
        }

        transaction.kindRaw = kind.rawValue
        transaction.amount = signedAmount
        if kind == .transfer {
            transaction.categoryID = nil
            transaction.subcategoryID = nil
            transaction.categorizationSourceRaw = CategorizationSource.manual.rawValue
            transaction.confidence = 1
            transaction.needsReview = false
            transaction.reviewStatusRaw = ReviewStatus.accepted.rawValue
            transaction.categorizationReason = "Marked manually as transfer."
        }
        transaction.updatedAt = .now
        try context.save()
    }
}
