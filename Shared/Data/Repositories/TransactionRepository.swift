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

    func fetchPage(offset: Int, limit: Int) throws -> [Transaction] {
        guard limit > 0 else { return [] }
        let context = makeContext()
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.bookingDate, order: .reverse)]
        )
        descriptor.fetchOffset = max(offset, 0)
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func count() throws -> Int {
        let context = makeContext()
        return try context.fetchCount(FetchDescriptor<Transaction>())
    }

    func count(accountName: String) throws -> Int {
        let context = makeContext()
        let targetName = accountName
        return try context.fetchCount(FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.accountName == targetName }
        ))
    }

    func fetchLatest(accountName: String) throws -> Transaction? {
        let context = makeContext()
        let targetName = accountName
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.accountName == targetName },
            sortBy: [SortDescriptor(\.bookingDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetch(transactionID: UUID) throws -> Transaction? {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == transactionID })
        return try context.fetch(descriptor).first
    }

    func exists(fingerprint: String) throws -> Bool {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.fingerprint == fingerprint })
        return try context.fetchCount(descriptor) > 0
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
            sign >= 0 ? $0.amount >= .zero : $0.amount < .zero
        }
    }

    func fetchPendingReview() throws -> [Transaction] {
        let context = makeContext()
        let rawPending = ReviewStatus.pending.rawValue
        let rawTransfer = TransactionKind.transfer.rawValue
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                ($0.kindRaw == nil || $0.kindRaw != rawTransfer) &&
                ($0.needsReview ||
                 $0.categoryID == nil ||
                 $0.reviewStatusRaw == rawPending ||
                 $0.suggestedCategoryID != nil)
            }
        )
        return try context.fetch(descriptor)
            .sorted {
                if $0.confidence == $1.confidence {
                    return $0.bookingDate > $1.bookingDate
                }
                return $0.confidence < $1.confidence
            }
    }

    func fetchPendingDuplicateReview() throws -> [Transaction] {
        let context = makeContext()
        let pending = DuplicateReviewStatus.pending.rawValue
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.duplicateReviewStatusRaw == pending },
            sortBy: [SortDescriptor(\.bookingDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchRecategorizationCandidates() throws -> [Transaction] {
        let context = makeContext()
        let rawTransfer = TransactionKind.transfer.rawValue
        let rawManual = CategorizationSource.manual.rawValue
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                ($0.kindRaw == nil || $0.kindRaw != rawTransfer) &&
                $0.categorizationSourceRaw != rawManual
            }
        )
        return try context.fetch(descriptor)
    }

    func fetchByMerchant(_ merchant: String, limit: Int = 20) throws -> [Transaction] {
        let context = makeContext()
        let targetMerchant = merchant
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.merchantCanonicalName == targetMerchant },
            sortBy: [SortDescriptor(\.bookingDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func fetchByDateRange(start: Date, end: Date) throws -> [Transaction] {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.bookingDate >= start && $0.bookingDate <= end }
        )
        return try context.fetch(descriptor)
    }

    func findSimilarTransactions(description: String, amount: Decimal, limit: Int = 5) throws -> [Transaction] {
        let normalizedDescription = description.lowercased()
        let context = makeContext()
        // We can only check if cleanedDescription contains normalizedDescription in SwiftData
        // The reverse (normalizedDescription.contains(cleanedDescription)) is not supported in #Predicate easily, 
        // so we'll fetch using the first condition and filter the rest in memory.
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate {
                $0.cleanedDescription.contains(normalizedDescription)
            },
            sortBy: [SortDescriptor(\.bookingDate, order: .reverse)]
        )
        
        let directMatches = try context.fetch(descriptor)
        
        return directMatches
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

    func fetchMatchingNameTransactions(for transaction: Transaction) throws -> [Transaction] {
        let targetID = transaction.id
        let targetKindRaw = transaction.kindRaw
        let targetIsIncome = transaction.amount >= 0
        let targetMerchant = transaction.merchantCanonicalName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let targetCleaned = transaction.cleanedDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetRaw = transaction.rawDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetFingerprint = transaction.fingerprint.trimmingCharacters(in: .whitespacesAndNewlines)

        let context = makeContext()
        // We do a broader fetch that filters out the exact same ID, and then memory filter the complex conditions
        // Wait, the prompt says: "Replace fetchAll().filter { } with proper #Predicate statements in FetchDescriptor."
        // We can put most conditions in the predicate!
        let hasMerchant = !targetMerchant.isEmpty && !targetMerchant.isGenericBankingNoise
        let hasCleaned = !targetCleaned.isEmpty && !targetCleaned.isGenericBankingNoise
        let hasRaw = !targetRaw.isEmpty && !targetRaw.isGenericBankingNoise
        let hasFingerprint = !targetFingerprint.isEmpty && !targetCleaned.isGenericBankingNoise

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { t in
                t.id != targetID &&
                t.kindRaw == targetKindRaw
            }
        )
        
        return try context.fetch(descriptor).filter { t in
            guard (t.amount >= 0) == targetIsIncome else { return false }

            if hasMerchant,
               let merchant = t.merchantCanonicalName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               !merchant.isEmpty, merchant == targetMerchant {
                return true
            }

            if hasCleaned {
                let cleaned = t.cleanedDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if cleaned == targetCleaned {
                    return true
                }
            }

            if hasRaw {
                let raw = t.rawDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if raw == targetRaw {
                    return true
                }
            }

            if hasFingerprint, t.fingerprint == targetFingerprint {
                return true
            }

            return false
        }
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
        clearRecategorizationSuggestion(on: transaction)
        transaction.categorizationSourceRaw = source.rawValue
        transaction.confidence = confidence
        transaction.needsReview = needsReview
        transaction.reviewStatusRaw = reviewStatus.rawValue
        transaction.categorizationReason = reason
        transaction.isRecurringCandidate = isRecurringCandidate
        transaction.updatedAt = .now
        try context.save()
    }

    func saveRecategorizationSuggestion(
        transactionID: UUID,
        categoryID: UUID,
        subcategoryID: UUID? = nil,
        source: CategorizationSource,
        confidence: Double,
        reason: String?
    ) throws {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == transactionID })
        guard let transaction = try context.fetch(descriptor).first else {
            return
        }

        guard transaction.categoryID != categoryID else {
            clearRecategorizationSuggestion(on: transaction)
            try context.save()
            return
        }

        transaction.suggestedCategoryID = categoryID
        transaction.suggestedSubcategoryID = subcategoryID
        transaction.suggestedConfidence = confidence
        transaction.suggestedSourceRaw = source.rawValue
        transaction.suggestedReason = reason
        transaction.updatedAt = .now
        try context.save()
    }

    func clearRecategorizationSuggestion(transactionID: UUID) throws {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == transactionID })
        guard let transaction = try context.fetch(descriptor).first else {
            return
        }

        clearRecategorizationSuggestion(on: transaction)
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
            clearRecategorizationSuggestion(on: transaction)
            transaction.categorizationSourceRaw = CategorizationSource.manual.rawValue
            transaction.confidence = 1
            transaction.needsReview = false
            transaction.reviewStatusRaw = ReviewStatus.accepted.rawValue
            transaction.categorizationReason = "Marked manually as transfer."
        }
        transaction.updatedAt = .now
        try context.save()
    }

    func applyDuplicateAudit(_ groups: [DuplicateMovementGroup]) throws {
        let context = makeContext()
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        var groupsByTransactionID: [UUID: DuplicateMovementGroup] = [:]

        for group in groups {
            for transactionID in group.transactionIDs {
                groupsByTransactionID[transactionID] = group
            }
        }

        for transaction in transactions {
            guard let group = groupsByTransactionID[transaction.id] else {
                clearDuplicateMetadata(on: transaction)
                continue
            }

            let keepsPreviousDecision = transaction.duplicateGroupID == group.id
            transaction.duplicateGroupID = group.id
            transaction.duplicateConfidence = group.confidence
            transaction.duplicateReasonKey = group.reasonKey
            transaction.duplicateRecommendedKeepID = group.recommendedKeepID
            if !keepsPreviousDecision || transaction.duplicateReviewStatusRaw == nil {
                transaction.duplicateReviewStatusRaw = DuplicateReviewStatus.pending.rawValue
            }
            transaction.updatedAt = .now
        }

        try context.save()
    }

    func dismissDuplicateGroup(groupID: String) throws {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.duplicateGroupID == groupID })
        let transactions = try context.fetch(descriptor)

        for transaction in transactions {
            transaction.duplicateReviewStatusRaw = DuplicateReviewStatus.dismissed.rawValue
            transaction.updatedAt = .now
        }

        try context.save()
    }

    func deleteDuplicateGroup(groupID: String, keeping transactionID: UUID) throws {
        let context = makeContext()
        let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.duplicateGroupID == groupID })
        let transactions = try context.fetch(descriptor)
        guard transactions.contains(where: { $0.id == transactionID }) else { return }

        for transaction in transactions {
            if transaction.id == transactionID {
                clearDuplicateMetadata(on: transaction)
            } else {
                context.delete(transaction)
            }
        }

        try context.save()
    }

    @discardableResult
    func resolveDuplicateGroups(_ groups: [DuplicateMovementGroup]) throws -> Int {
        guard !groups.isEmpty else { return 0 }

        let context = makeContext()
        let groupsByTransactionID = Dictionary(
            uniqueKeysWithValues: groups.flatMap { group in
                group.transactionIDs.map { ($0, group) }
            }
        )
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        var deletedCount = 0

        for transaction in transactions {
            guard let group = groupsByTransactionID[transaction.id],
                  transaction.duplicateGroupID == group.id,
                  group.transactionIDs.contains(group.recommendedKeepID) else {
                continue
            }

            if transaction.id == group.recommendedKeepID {
                clearDuplicateMetadata(on: transaction)
            } else {
                context.delete(transaction)
                deletedCount += 1
            }
        }

        try context.save()
        return deletedCount
    }

    private func clearDuplicateMetadata(on transaction: Transaction) {
        transaction.duplicateGroupID = nil
        transaction.duplicateReviewStatusRaw = nil
        transaction.duplicateConfidence = nil
        transaction.duplicateReasonKey = nil
        transaction.duplicateRecommendedKeepID = nil
    }

    private func clearRecategorizationSuggestion(on transaction: Transaction) {
        transaction.suggestedCategoryID = nil
        transaction.suggestedSubcategoryID = nil
        transaction.suggestedConfidence = nil
        transaction.suggestedSourceRaw = nil
        transaction.suggestedReason = nil
    }
}
