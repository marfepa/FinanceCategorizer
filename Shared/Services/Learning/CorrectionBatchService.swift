import Foundation
import SwiftData
import os

/// User actions that the review queue records as one undoable unit.
enum CorrectionAction: String {
    case approve
    case reassign
    case acceptSuggestion
    case applyToSimilar
    case acceptHighConfidence
    case markAsTransfer
    case confirmTransferPair
}

struct CorrectionRequest {
    let transactionID: UUID
    let categoryID: UUID
    let subcategoryID: UUID?

    init(transactionID: UUID, categoryID: UUID, subcategoryID: UUID? = nil) {
        self.transactionID = transactionID
        self.categoryID = categoryID
        self.subcategoryID = subcategoryID
    }
}

/// How a correction may create categorization rules.
enum CorrectionRulePolicy {
    /// Never create rules.
    case none
    /// Create a rule only for explicit requests (the user asked for it).
    case explicit
    /// Legacy behaviour kept for screens outside the review queue: create a rule
    /// when asked or when the rule suggestion engine considers it safe.
    case explicitOrSuggested
}

enum CorrectionBatchError: LocalizedError {
    case transactionNotFound
    case batchNotFound
    case conflictingLaterChanges
    case transferPairNoLongerValid

    var errorDescription: String? {
        let language = AppLanguage.currentSelection
        switch self {
        case .transactionNotFound:
            return language.localized("review.undo.error.transactionNotFound")
        case .batchNotFound:
            return language.localized("review.undo.error.batchNotFound")
        case .conflictingLaterChanges:
            return language.localized("review.undo.error.conflict")
        case .transferPairNoLongerValid:
            return language.localized("review.transferPair.error.changed")
        }
    }
}

/// Everything needed to put a batch of corrections back exactly as it was.
/// Undo history is session-only by design, so it lives in memory.
struct CorrectionBatch: Identifiable {
    struct TransactionState {
        let transactionID: UUID
        let categoryID: UUID?
        let subcategoryID: UUID?
        let suggestedCategoryID: UUID?
        let suggestedSubcategoryID: UUID?
        let suggestedConfidence: Double?
        let suggestedSourceRaw: String?
        let suggestedReason: String?
        let categorizationSourceRaw: String
        let confidence: Double
        let needsReview: Bool
        let reviewStatusRaw: String
        let categorizationReason: String?
        let isRecurringCandidate: Bool
        let kindRaw: String?
        let amount: Decimal
        let updatedAt: Date

        init(_ transaction: Transaction) {
            transactionID = transaction.id
            categoryID = transaction.categoryID
            subcategoryID = transaction.subcategoryID
            suggestedCategoryID = transaction.suggestedCategoryID
            suggestedSubcategoryID = transaction.suggestedSubcategoryID
            suggestedConfidence = transaction.suggestedConfidence
            suggestedSourceRaw = transaction.suggestedSourceRaw
            suggestedReason = transaction.suggestedReason
            categorizationSourceRaw = transaction.categorizationSourceRaw
            confidence = transaction.confidence
            needsReview = transaction.needsReview
            reviewStatusRaw = transaction.reviewStatusRaw
            categorizationReason = transaction.categorizationReason
            isRecurringCandidate = transaction.isRecurringCandidate
            kindRaw = transaction.kindRaw
            amount = transaction.amount
            updatedAt = transaction.updatedAt
        }

        func restore(on transaction: Transaction) {
            transaction.categoryID = categoryID
            transaction.subcategoryID = subcategoryID
            transaction.suggestedCategoryID = suggestedCategoryID
            transaction.suggestedSubcategoryID = suggestedSubcategoryID
            transaction.suggestedConfidence = suggestedConfidence
            transaction.suggestedSourceRaw = suggestedSourceRaw
            transaction.suggestedReason = suggestedReason
            transaction.categorizationSourceRaw = categorizationSourceRaw
            transaction.confidence = confidence
            transaction.needsReview = needsReview
            transaction.reviewStatusRaw = reviewStatusRaw
            transaction.categorizationReason = categorizationReason
            transaction.isRecurringCandidate = isRecurringCandidate
            transaction.kindRaw = kindRaw
            transaction.amount = amount
            transaction.updatedAt = updatedAt
        }
    }

    struct MerchantState {
        let merchantID: UUID
        let normalizedName: String
        let displayName: String
        let usageCount: Int
        let preferredCategoryID: UUID?
        let averageConfidence: Double
        let lastSeenAt: Date?

        init(_ merchant: Merchant) {
            merchantID = merchant.id
            normalizedName = merchant.normalizedName
            displayName = merchant.displayName
            usageCount = merchant.usageCount
            preferredCategoryID = merchant.preferredCategoryID
            averageConfidence = merchant.averageConfidence
            lastSeenAt = merchant.lastSeenAt
        }

        func restore(on merchant: Merchant) {
            merchant.normalizedName = normalizedName
            merchant.displayName = displayName
            merchant.usageCount = usageCount
            merchant.preferredCategoryID = preferredCategoryID
            merchant.averageConfidence = averageConfidence
            merchant.lastSeenAt = lastSeenAt
        }
    }

    struct RuleState {
        let ruleID: UUID
        let name: String
        let isEnabled: Bool
        let amountMin: Decimal?
        let amountMax: Decimal?
        let amountSign: Int?
        let targetCategoryID: UUID
        let priority: Int
        let createdFromUserCorrection: Bool

        init(_ rule: Rule) {
            ruleID = rule.id
            name = rule.name
            isEnabled = rule.isEnabled
            amountMin = rule.amountMin
            amountMax = rule.amountMax
            amountSign = rule.amountSign
            targetCategoryID = rule.targetCategoryID
            priority = rule.priority
            createdFromUserCorrection = rule.createdFromUserCorrection
        }

        func restore(on rule: Rule) {
            rule.name = name
            rule.isEnabled = isEnabled
            rule.amountMin = amountMin
            rule.amountMax = amountMax
            rule.amountSign = amountSign
            rule.targetCategoryID = targetCategoryID
            rule.priority = priority
            rule.createdFromUserCorrection = createdFromUserCorrection
        }
    }

    let id: UUID
    let action: CorrectionAction
    let appliedAt: Date
    /// Movements the user acted on explicitly.
    let explicitCount: Int
    /// Additional historical movements updated because they match by name.
    let propagatedCount: Int
    /// Description of the first movement, for feedback messages.
    let primaryDescription: String?
    /// The first explicit movement would make a good rule, but none was created.
    let ruleSuggestionTransactionID: UUID?
    let ruleSuggestionCategoryID: UUID?

    fileprivate let transactionStates: [TransactionState]
    fileprivate let insertedCorrectionIDs: [UUID]
    fileprivate let insertedMerchantIDs: [UUID]
    fileprivate let modifiedMerchants: [MerchantState]
    fileprivate let insertedRuleIDs: [UUID]
    fileprivate let modifiedRules: [RuleState]

    var totalCount: Int { explicitCount + propagatedCount }
    var transactionIDs: [UUID] { transactionStates.map(\.transactionID) }
    var hasRuleSuggestion: Bool { ruleSuggestionTransactionID != nil }
    var createdRuleCount: Int { insertedRuleIDs.count + modifiedRules.count }
}

/// Applies review decisions as a single SwiftData save and keeps a short
/// session history so each batch can be reverted.
@MainActor
final class CorrectionBatchService {
    static let historyLimit = 20

    private let modelContainer: ModelContainer
    private let ruleSuggestionEngine: RuleSuggestionEngine
    private let localModelManager: LocalModelManager
    private let directionPolicy = CategoryDirectionPolicy()
    private let logger = Logger(subsystem: "com.mariofernandez.FinanceCategorizer", category: "CorrectionBatch")

    private(set) var history: [CorrectionBatch] = []
    private var revertedBatchIDs: Set<UUID> = []
    /// Test hook: throw right before saving so atomicity can be verified.
    var failBeforeSaveForTesting = false

    init(modelContainer: ModelContainer, ruleSuggestionEngine: RuleSuggestionEngine, localModelManager: LocalModelManager) {
        self.modelContainer = modelContainer
        self.ruleSuggestionEngine = ruleSuggestionEngine
        self.localModelManager = localModelManager
    }

    func isReverted(_ batchID: UUID) -> Bool {
        revertedBatchIDs.contains(batchID)
    }

    // MARK: Preview

    /// Number of extra historical movements that propagation would update for
    /// these explicit movements. Manual decisions are never counted.
    func propagationCount(for transactionIDs: [UUID]) throws -> Int {
        let context = ModelContext(modelContainer)
        let all = try context.fetch(FetchDescriptor<Transaction>())
        let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let explicitIDs = Set(transactionIDs)
        let targets = transactionIDs.compactMap { byID[$0] }
        return propagationTargets(for: targets, in: all, excluding: explicitIDs).count
    }

    /// Keeps only the movements whose direction is compatible with the category,
    /// so a confirmed batch never fails on a single odd movement.
    func compatibleTransactionIDs(_ transactionIDs: [UUID], categoryID: UUID) throws -> [UUID] {
        let context = ModelContext(modelContainer)
        let categoryDescriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == categoryID })
        guard let category = try context.fetch(categoryDescriptor).first else { return [] }
        let wanted = Set(transactionIDs)
        let compatible = Set(try context.fetch(FetchDescriptor<Transaction>())
            .filter { wanted.contains($0.id) && directionPolicy.isCompatible(categoryIsIncome: category.isIncome, transactionKind: $0.resolvedKind) }
            .map(\.id))
        return transactionIDs.filter(compatible.contains)
    }

    // MARK: Apply

    @discardableResult
    func applyCategories(
        _ requests: [CorrectionRequest],
        action: CorrectionAction,
        propagateToMatches: Bool,
        rulePolicy: CorrectionRulePolicy,
        createRules: Bool,
        recordHistory: Bool = true
    ) throws -> CorrectionBatch {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        let appliedAt = Date.now

        do {
            let all = try context.fetch(FetchDescriptor<Transaction>())
            let byID = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let categories = try context.fetch(FetchDescriptor<Category>())
            let categoriesByID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            var recorder = BatchRecorder()
            var explicitTransactions: [(Transaction, CorrectionRequest)] = []

            for request in requests {
                guard let transaction = byID[request.transactionID] else {
                    throw CorrectionBatchError.transactionNotFound
                }
                guard let category = categoriesByID[request.categoryID],
                      directionPolicy.isCompatible(categoryIsIncome: category.isIncome, transactionKind: transaction.resolvedKind) else {
                    throw CategoryDirectionError.incompatibleCategory
                }
                explicitTransactions.append((transaction, request))
            }

            // Evaluate rule suggestions on the state the user saw, before mutating anything.
            let firstExplicit = explicitTransactions.first
            let ruleSuggestions = explicitTransactions.map {
                ruleSuggestionEngine.shouldSuggestRule(for: $0.0, categoryID: $0.1.categoryID)
            }
            let suggestsRule = (ruleSuggestions.first ?? false) || firstExplicit.map {
                isConfidentSuggestion($0.0, categoryID: $0.1.categoryID)
            } ?? false

            for (transaction, request) in explicitTransactions {
                applyCorrection(
                    to: transaction,
                    categoryID: request.categoryID,
                    subcategoryID: request.subcategoryID,
                    reason: "Corrected manually by the user.",
                    context: context,
                    recorder: &recorder,
                    appliedAt: appliedAt
                )
            }

            var propagatedCount = 0
            if propagateToMatches {
                let explicitIDs = Set(requests.map(\.transactionID))
                for (transaction, request) in explicitTransactions {
                    let targets = propagationTargets(for: [transaction], in: all, excluding: explicitIDs.union(recorder.touchedIDs))
                    for match in targets {
                        applyCorrection(
                            to: match,
                            categoryID: request.categoryID,
                            subcategoryID: request.subcategoryID,
                            reason: "Automatically updated from user recategorization of matching transaction.",
                            context: context,
                            recorder: &recorder,
                            appliedAt: appliedAt
                        )
                        propagatedCount += 1
                    }
                }
            }

            var createdOrUpdatedRule = false
            var merchants = try context.fetch(FetchDescriptor<Merchant>())
            var rules = try context.fetch(FetchDescriptor<Rule>())
            for (index, (transaction, request)) in explicitTransactions.enumerated() {
                recordMerchantMemory(for: transaction, categoryID: request.categoryID, merchants: &merchants, context: context, recorder: &recorder)
                let wantsRule: Bool
                switch rulePolicy {
                case .none:
                    wantsRule = false
                case .explicit:
                    wantsRule = createRules
                case .explicitOrSuggested:
                    wantsRule = createRules || ruleSuggestions[index]
                }
                if wantsRule {
                    createdOrUpdatedRule = upsertRule(for: transaction, categoryID: request.categoryID, rules: &rules, context: context, recorder: &recorder) || createdOrUpdatedRule
                }
            }

            if failBeforeSaveForTesting {
                throw CocoaError(.coderInvalidValue)
            }
            try context.save()

            let batch = CorrectionBatch(
                id: UUID(),
                action: action,
                appliedAt: appliedAt,
                explicitCount: explicitTransactions.count,
                propagatedCount: propagatedCount,
                primaryDescription: firstExplicit?.0.rawDescription,
                ruleSuggestionTransactionID: (suggestsRule && !createdOrUpdatedRule && rulePolicy == .explicit) ? firstExplicit?.0.id : nil,
                ruleSuggestionCategoryID: (suggestsRule && !createdOrUpdatedRule && rulePolicy == .explicit) ? firstExplicit?.1.categoryID : nil,
                transactionStates: recorder.transactionStates,
                insertedCorrectionIDs: recorder.insertedCorrectionIDs,
                insertedMerchantIDs: recorder.insertedMerchantIDs,
                modifiedMerchants: recorder.modifiedMerchants,
                insertedRuleIDs: recorder.insertedRuleIDs,
                modifiedRules: recorder.modifiedRules
            )
            if recordHistory {
                remember(batch)
            }
            rebuildModelAfterCommit()
            return batch
        } catch {
            context.rollback()
            throw error
        }
    }

    @discardableResult
    func markAsTransfer(transactionID: UUID) throws -> CorrectionBatch {
        try markAsTransfer(transactionIDs: [transactionID], action: .markAsTransfer, reason: "Marked manually as transfer.")
    }

    /// Marks both sides of a confirmed transfer between own accounts in one
    /// undoable batch.
    @discardableResult
    func markAsTransferPair(outgoingID: UUID, incomingID: UUID) throws -> CorrectionBatch {
        try markAsTransfer(
            transactionIDs: [outgoingID, incomingID],
            action: .confirmTransferPair,
            reason: "Paired with a matching movement in another account as an internal transfer."
        )
    }

    private func markAsTransfer(transactionIDs: [UUID], action: CorrectionAction, reason: String) throws -> CorrectionBatch {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        let appliedAt = Date.now
        do {
            var states: [CorrectionBatch.TransactionState] = []
            var firstDescription: String?
            for transactionID in transactionIDs {
                let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == transactionID })
                guard let transaction = try context.fetch(descriptor).first else {
                    throw CorrectionBatchError.transactionNotFound
                }
                if action == .confirmTransferPair {
                    // The proposal is a snapshot: never overwrite a decision made since.
                    let kind = transaction.resolvedKind
                    guard kind != .transfer, kind != .adjustment,
                          transaction.categorizationSourceRaw != CategorizationSource.manual.rawValue else {
                        throw CorrectionBatchError.transferPairNoLongerValid
                    }
                }
                states.append(CorrectionBatch.TransactionState(transaction))
                firstDescription = firstDescription ?? transaction.rawDescription

                transaction.kindRaw = TransactionKind.transfer.rawValue
                transaction.categoryID = nil
                transaction.subcategoryID = nil
                clearSuggestion(on: transaction)
                transaction.categorizationSourceRaw = CategorizationSource.manual.rawValue
                transaction.confidence = 1
                transaction.needsReview = false
                transaction.reviewStatusRaw = ReviewStatus.accepted.rawValue
                transaction.categorizationReason = reason
                transaction.updatedAt = appliedAt
            }

            if failBeforeSaveForTesting {
                throw CocoaError(.coderInvalidValue)
            }
            try context.save()

            let batch = CorrectionBatch(
                id: UUID(),
                action: action,
                appliedAt: appliedAt,
                explicitCount: states.count,
                propagatedCount: 0,
                primaryDescription: firstDescription,
                ruleSuggestionTransactionID: nil,
                ruleSuggestionCategoryID: nil,
                transactionStates: states,
                insertedCorrectionIDs: [],
                insertedMerchantIDs: [],
                modifiedMerchants: [],
                insertedRuleIDs: [],
                modifiedRules: []
            )
            remember(batch)
            return batch
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Creates the rule a previous batch suggested. Returned as its own batch so
    /// it can be undone independently.
    @discardableResult
    func createSuggestedRule(from batch: CorrectionBatch) throws -> CorrectionBatch? {
        guard let transactionID = batch.ruleSuggestionTransactionID,
              let categoryID = batch.ruleSuggestionCategoryID else { return nil }
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        do {
            let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == transactionID })
            guard let transaction = try context.fetch(descriptor).first else {
                throw CorrectionBatchError.transactionNotFound
            }
            var recorder = BatchRecorder()
            var rules = try context.fetch(FetchDescriptor<Rule>())
            guard upsertRule(for: transaction, categoryID: categoryID, rules: &rules, context: context, recorder: &recorder) else {
                return nil
            }
            try context.save()
            let ruleBatch = CorrectionBatch(
                id: UUID(),
                action: batch.action,
                appliedAt: .now,
                explicitCount: 0,
                propagatedCount: 0,
                primaryDescription: transaction.rawDescription,
                ruleSuggestionTransactionID: nil,
                ruleSuggestionCategoryID: nil,
                transactionStates: [],
                insertedCorrectionIDs: [],
                insertedMerchantIDs: [],
                modifiedMerchants: [],
                insertedRuleIDs: recorder.insertedRuleIDs,
                modifiedRules: recorder.modifiedRules
            )
            remember(ruleBatch)
            return ruleBatch
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Revert

    /// Puts every movement, correction record, merchant memory and rule touched
    /// by the batch back to its previous state in one save. Reverting twice is a no-op.
    func revert(batchID: UUID) throws {
        guard !revertedBatchIDs.contains(batchID) else { return }
        guard let batch = history.first(where: { $0.id == batchID }) else {
            throw CorrectionBatchError.batchNotFound
        }

        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        do {
            let transactionIDs = Set(batch.transactionStates.map(\.transactionID))
            let transactions = try context.fetch(FetchDescriptor<Transaction>()).filter { transactionIDs.contains($0.id) }
            let transactionsByID = Dictionary(transactions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            // A later edit to the same movement would be silently lost; refuse instead.
            for state in batch.transactionStates {
                guard let transaction = transactionsByID[state.transactionID] else {
                    throw CorrectionBatchError.transactionNotFound
                }
                if transaction.updatedAt != batch.appliedAt {
                    throw CorrectionBatchError.conflictingLaterChanges
                }
            }
            for state in batch.transactionStates {
                if let transaction = transactionsByID[state.transactionID] {
                    state.restore(on: transaction)
                }
            }

            if !batch.insertedCorrectionIDs.isEmpty {
                let ids = Set(batch.insertedCorrectionIDs)
                for correction in try context.fetch(FetchDescriptor<UserCorrection>()) where ids.contains(correction.id) {
                    context.delete(correction)
                }
            }

            if !batch.insertedMerchantIDs.isEmpty || !batch.modifiedMerchants.isEmpty {
                let merchants = try context.fetch(FetchDescriptor<Merchant>())
                let inserted = Set(batch.insertedMerchantIDs)
                let modified = Dictionary(batch.modifiedMerchants.map { ($0.merchantID, $0) }, uniquingKeysWith: { first, _ in first })
                for merchant in merchants {
                    if inserted.contains(merchant.id) {
                        context.delete(merchant)
                    } else if let state = modified[merchant.id] {
                        state.restore(on: merchant)
                    }
                }
            }

            if !batch.insertedRuleIDs.isEmpty || !batch.modifiedRules.isEmpty {
                let rules = try context.fetch(FetchDescriptor<Rule>())
                let inserted = Set(batch.insertedRuleIDs)
                let modified = Dictionary(batch.modifiedRules.map { ($0.ruleID, $0) }, uniquingKeysWith: { first, _ in first })
                for rule in rules {
                    if inserted.contains(rule.id) {
                        context.delete(rule)
                    } else if let state = modified[rule.id] {
                        state.restore(on: rule)
                    }
                }
            }

            if failBeforeSaveForTesting {
                throw CocoaError(.coderInvalidValue)
            }
            try context.save()
            revertedBatchIDs.insert(batchID)
            rebuildModelAfterCommit()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Internals

    private struct BatchRecorder {
        var transactionStates: [CorrectionBatch.TransactionState] = []
        var touchedIDs: Set<UUID> = []
        var insertedCorrectionIDs: [UUID] = []
        var insertedMerchantIDs: [UUID] = []
        var modifiedMerchants: [CorrectionBatch.MerchantState] = []
        var touchedMerchantIDs: Set<UUID> = []
        var insertedRuleIDs: [UUID] = []
        var modifiedRules: [CorrectionBatch.RuleState] = []
        var touchedRuleIDs: Set<UUID> = []
    }

    private func isConfidentSuggestion(_ transaction: Transaction, categoryID: UUID) -> Bool {
        guard let merchant = transaction.merchantCanonicalName, !merchant.isEmpty else { return false }
        return transaction.suggestedCategoryID == categoryID &&
            (transaction.suggestedConfidence ?? 0) >= AppConfig.softAutoCategorizationThreshold
    }

    private func propagationTargets(for targets: [Transaction], in all: [Transaction], excluding excludedIDs: Set<UUID>) -> [Transaction] {
        let matchers = targets.map(TransactionNameMatcher.init(target:))
        let manual = CategorizationSource.manual.rawValue
        return all.filter { candidate in
            !excludedIDs.contains(candidate.id) &&
            candidate.categorizationSourceRaw != manual &&
            matchers.contains { $0.matches(candidate) }
        }
    }

    private func applyCorrection(
        to transaction: Transaction,
        categoryID: UUID,
        subcategoryID: UUID?,
        reason: String,
        context: ModelContext,
        recorder: inout BatchRecorder,
        appliedAt: Date
    ) {
        if !recorder.touchedIDs.contains(transaction.id) {
            recorder.transactionStates.append(CorrectionBatch.TransactionState(transaction))
            recorder.touchedIDs.insert(transaction.id)
        }

        let correction = UserCorrection(
            transactionID: transaction.id,
            previousCategoryID: transaction.categoryID,
            newCategoryID: categoryID,
            previousSubcategoryID: transaction.subcategoryID,
            newSubcategoryID: subcategoryID,
            previousConfidence: transaction.confidence,
            originalSourceRaw: transaction.categorizationSourceRaw,
            correctedAt: appliedAt
        )
        context.insert(correction)
        recorder.insertedCorrectionIDs.append(correction.id)

        transaction.categoryID = categoryID
        transaction.subcategoryID = subcategoryID
        clearSuggestion(on: transaction)
        transaction.categorizationSourceRaw = CategorizationSource.manual.rawValue
        transaction.confidence = 1.0
        transaction.needsReview = false
        transaction.reviewStatusRaw = ReviewStatus.corrected.rawValue
        transaction.categorizationReason = reason
        transaction.updatedAt = appliedAt
    }

    private func clearSuggestion(on transaction: Transaction) {
        transaction.suggestedCategoryID = nil
        transaction.suggestedSubcategoryID = nil
        transaction.suggestedConfidence = nil
        transaction.suggestedSourceRaw = nil
        transaction.suggestedReason = nil
    }

    private func recordMerchantMemory(
        for transaction: Transaction,
        categoryID: UUID,
        merchants: inout [Merchant],
        context: ModelContext,
        recorder: inout BatchRecorder
    ) {
        guard let merchantName = transaction.merchantCanonicalName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !merchantName.isEmpty, !merchantName.isGenericBankingNoise else { return }

        let normalized = merchantName.lowercased()
        let displayName = transaction.merchantDisplayName ?? merchantName
        if let existing = merchants.first(where: { $0.canonicalName.caseInsensitiveCompare(merchantName) == .orderedSame }) {
            if !recorder.touchedMerchantIDs.contains(existing.id) {
                recorder.modifiedMerchants.append(CorrectionBatch.MerchantState(existing))
                recorder.touchedMerchantIDs.insert(existing.id)
            }
            existing.displayName = displayName
            existing.normalizedName = normalized
            existing.usageCount += 1
            existing.lastSeenAt = .now
            existing.averageConfidence = ((existing.averageConfidence * Double(max(existing.usageCount - 1, 0))) + 1.0) / Double(max(existing.usageCount, 1))
            existing.preferredCategoryID = categoryID
        } else {
            let merchant = Merchant(
                normalizedName: normalized,
                displayName: displayName,
                canonicalName: merchantName,
                usageCount: 1,
                preferredCategoryID: categoryID,
                averageConfidence: 1.0,
                lastSeenAt: .now
            )
            context.insert(merchant)
            merchants.append(merchant)
            recorder.insertedMerchantIDs.append(merchant.id)
            recorder.touchedMerchantIDs.insert(merchant.id)
        }
    }

    /// Mirrors `RuleRepository.createRule` inside the batch context.
    /// Returns false when the movement has no usable text to build a rule from.
    private func upsertRule(
        for transaction: Transaction,
        categoryID: UUID,
        rules: inout [Rule],
        context: ModelContext,
        recorder: inout BatchRecorder
    ) -> Bool {
        let merchantName = transaction.merchantCanonicalName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanedDesc = transaction.cleanedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDesc = transaction.rawDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        let name: String
        let merchantContains: String
        let descriptionContains: String
        if !merchantName.isEmpty, !merchantName.isGenericBankingNoise {
            name = "Rule for \(merchantName)"
            merchantContains = merchantName.lowercased()
            descriptionContains = ""
        } else if !cleanedDesc.isEmpty || !rawDesc.isEmpty {
            let targetText = !cleanedDesc.isEmpty ? cleanedDesc : rawDesc
            guard !targetText.lowercased().isGenericBankingNoise else { return false }
            name = "Rule for \(targetText)"
            merchantContains = ""
            descriptionContains = targetText.lowercased()
        } else {
            return false
        }
        let amountSign = transaction.amount < 0 ? -1 : 1

        let existing = rules.first { rule in
            let mMatch = (merchantContains.isEmpty && (rule.merchantContains == nil || rule.merchantContains?.isEmpty == true)) ||
                (!merchantContains.isEmpty && rule.merchantContains?.lowercased() == merchantContains)
            let dMatch = (descriptionContains.isEmpty && (rule.descriptionContains == nil || rule.descriptionContains?.isEmpty == true)) ||
                (!descriptionContains.isEmpty && rule.descriptionContains?.lowercased() == descriptionContains)
            return mMatch && dMatch
        }

        if let existing {
            if !recorder.touchedRuleIDs.contains(existing.id) {
                recorder.modifiedRules.append(CorrectionBatch.RuleState(existing))
                recorder.touchedRuleIDs.insert(existing.id)
            }
            existing.targetCategoryID = categoryID
            existing.name = name
            existing.isEnabled = true
            existing.priority = 200
            existing.createdFromUserCorrection = true
            existing.amountSign = amountSign
            return true
        }

        let rule = Rule(
            name: name,
            isEnabled: true,
            merchantContains: merchantContains,
            descriptionContains: descriptionContains,
            amountMin: nil,
            amountMax: nil,
            amountSign: amountSign,
            targetCategoryID: categoryID,
            targetSubcategoryID: nil,
            priority: 200,
            createdFromUserCorrection: true,
            hitCount: 0
        )
        context.insert(rule)
        rules.append(rule)
        recorder.insertedRuleIDs.append(rule.id)
        recorder.touchedRuleIDs.insert(rule.id)
        return true
    }

    private func remember(_ batch: CorrectionBatch) {
        history.insert(batch, at: 0)
        if history.count > Self.historyLimit {
            let dropped = history.removeLast()
            revertedBatchIDs.remove(dropped.id)
        }
    }

    /// The local model is derived data: failing to rebuild it must never undo
    /// a committed decision.
    private func rebuildModelAfterCommit() {
        do {
            try localModelManager.rebuildModelIfNeeded()
        } catch {
            logger.error("Local model rebuild after correction failed: \(error.localizedDescription)")
        }
    }
}
