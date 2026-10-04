import XCTest
import SwiftData
#if os(macOS)
@testable import FinanceCategorizerMac
#else
@testable import FinanceCategorizerIOS
#endif

@MainActor
final class CorrectionBatchServiceTests: XCTestCase {
    private var container: AppContainer!
    private var groceriesID: UUID!
    private var leisureID: UUID!
    private var salaryID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.set(AppLanguage.spanish.rawValue, forKey: "appLanguage")
        container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let categories = try container.categoryRepository.fetchAll()
        groceriesID = try XCTUnwrap(categories.first { $0.name == "Alimentacion" }).id
        leisureID = try XCTUnwrap(categories.first { $0.name == "Ocio" }).id
        salaryID = try XCTUnwrap(categories.first { $0.isIncome }).id
    }

    // MARK: Helpers

    private func makeExpense(
        _ description: String,
        merchant: String? = nil,
        categoryID: UUID? = nil,
        source: CategorizationSource = .unknown,
        confidence: Double = 0.3,
        reviewStatus: ReviewStatus = .pending,
        fingerprint: String = UUID().uuidString
    ) throws -> Transaction {
        let transaction = Transaction(
            bookingDate: .now,
            rawDescription: description,
            cleanedDescription: description,
            merchantDisplayName: merchant,
            merchantCanonicalName: merchant,
            amount: Decimal(-12.5),
            kindRaw: TransactionKind.expense.rawValue,
            categoryID: categoryID,
            categorizationSourceRaw: source.rawValue,
            confidence: confidence,
            needsReview: reviewStatus == .pending,
            reviewStatusRaw: reviewStatus.rawValue,
            categorizationReason: "original reason",
            fingerprint: fingerprint
        )
        try container.transactionRepository.insert(transaction)
        return transaction
    }

    private func fetch(_ transaction: Transaction) throws -> Transaction {
        try XCTUnwrap(container.transactionRepository.fetch(transactionID: transaction.id))
    }

    private var service: CorrectionBatchService { container.correctionBatchService }

    // MARK: Scope

    func testApproveInReviewQueueOnlyChangesSelectedMovement() throws {
        let selected = try makeExpense("NETFLIX", merchant: "Netflix")
        let sibling = try makeExpense("NETFLIX", merchant: "Netflix")

        let viewModel = ReviewQueueViewModel()
        viewModel.load(using: container)
        viewModel.select(try XCTUnwrap(viewModel.transactions.first { $0.id == selected.id }))
        viewModel.selectedCategoryID = leisureID
        viewModel.approveSelected(using: container)

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(try fetch(selected).categoryID, leisureID)
        XCTAssertNil(try fetch(sibling).categoryID, "Approving must not cascade silently to other movements")
        XCTAssertTrue(try fetch(sibling).needsReview)
        XCTAssertEqual(viewModel.lastBatch?.totalCount, 1)
    }

    func testPropagationNeverOverwritesManualDecisions() throws {
        let selected = try makeExpense("NETFLIX", merchant: "Netflix")
        let automatic = try makeExpense("NETFLIX", merchant: "Netflix", categoryID: groceriesID, source: .rule, confidence: 0.8, reviewStatus: .accepted)
        let manual = try makeExpense("NETFLIX", merchant: "Netflix", categoryID: groceriesID, source: .manual, confidence: 1, reviewStatus: .corrected)

        XCTAssertEqual(try service.propagationCount(for: [selected.id]), 1)

        let batch = try service.applyCategories(
            [CorrectionRequest(transactionID: selected.id, categoryID: leisureID)],
            action: .applyToSimilar,
            propagateToMatches: true,
            rulePolicy: .none,
            createRules: false
        )

        XCTAssertEqual(batch.explicitCount, 1)
        XCTAssertEqual(batch.propagatedCount, 1)
        XCTAssertEqual(try fetch(automatic).categoryID, leisureID)
        XCTAssertEqual(try fetch(manual).categoryID, groceriesID, "A manual decision must never be overwritten by propagation")
    }

    func testIncompatibleCategoryIsRejectedWithoutChanges() throws {
        let expense = try makeExpense("MERCADONA", merchant: "Mercadona")
        XCTAssertThrowsError(try service.applyCategories(
            [CorrectionRequest(transactionID: expense.id, categoryID: salaryID)],
            action: .approve,
            propagateToMatches: false,
            rulePolicy: .none,
            createRules: false
        ))
        XCTAssertNil(try fetch(expense).categoryID)
        XCTAssertTrue(service.history.isEmpty)
    }

    // MARK: Undo

    func testRevertRestoresMovementsCorrectionsMerchantMemoryAndRules() throws {
        let selected = try makeExpense("NETFLIX", merchant: "Netflix", categoryID: groceriesID, source: .localML, confidence: 0.5)
        let sibling = try makeExpense("NETFLIX", merchant: "Netflix")
        let before = try fetch(selected)
        let beforeUpdatedAt = before.updatedAt

        let batch = try service.applyCategories(
            [CorrectionRequest(transactionID: selected.id, categoryID: leisureID)],
            action: .applyToSimilar,
            propagateToMatches: true,
            rulePolicy: .explicit,
            createRules: true
        )
        XCTAssertEqual(batch.totalCount, 2)
        XCTAssertEqual(try container.correctionRepository.fetchAll().count, 2)
        XCTAssertEqual(try container.ruleRepository.fetchAll().filter(\.createdFromUserCorrection).count, 1)
        XCTAssertEqual(try container.merchantRepository.preferredCategoryID(for: "Netflix"), leisureID)

        try service.revert(batchID: batch.id)

        let restored = try fetch(selected)
        XCTAssertEqual(restored.categoryID, groceriesID)
        XCTAssertEqual(restored.categorizationSourceRaw, CategorizationSource.localML.rawValue)
        XCTAssertEqual(restored.confidence, 0.5)
        XCTAssertTrue(restored.needsReview)
        XCTAssertEqual(restored.reviewStatusRaw, ReviewStatus.pending.rawValue)
        XCTAssertEqual(restored.categorizationReason, "original reason")
        XCTAssertEqual(restored.updatedAt, beforeUpdatedAt)
        XCTAssertNil(try fetch(sibling).categoryID)
        XCTAssertTrue(try fetch(sibling).needsReview)
        XCTAssertTrue(try container.correctionRepository.fetchAll().isEmpty)
        XCTAssertTrue(try container.ruleRepository.fetchAll().filter(\.createdFromUserCorrection).isEmpty)
        XCTAssertNil(try container.merchantRepository.preferredCategoryID(for: "Netflix"))

        // Reverting twice is a harmless no-op.
        XCTAssertNoThrow(try service.revert(batchID: batch.id))
    }

    func testRevertRestoresPreviouslyExistingRuleInsteadOfDeletingIt() throws {
        let transaction = try makeExpense("NETFLIX", merchant: "Netflix")
        try container.ruleRepository.createRule(
            name: "Existing",
            merchantContains: "netflix",
            amountSign: -1,
            targetCategoryID: groceriesID,
            createdFromUserCorrection: false
        )

        let batch = try service.applyCategories(
            [CorrectionRequest(transactionID: transaction.id, categoryID: leisureID)],
            action: .reassign,
            propagateToMatches: false,
            rulePolicy: .explicit,
            createRules: true
        )
        XCTAssertEqual(try container.ruleRepository.fetchAll().first?.targetCategoryID, leisureID)

        try service.revert(batchID: batch.id)

        let rules = try container.ruleRepository.fetchAll()
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.name, "Existing")
        XCTAssertEqual(rules.first?.targetCategoryID, groceriesID)
    }

    func testMarkAsTransferCanBeUndone() throws {
        let transaction = try makeExpense("TRASPASO", categoryID: groceriesID, source: .rule, confidence: 0.7)

        let batch = try service.markAsTransfer(transactionID: transaction.id)
        XCTAssertEqual(try fetch(transaction).resolvedKind, .transfer)
        XCTAssertNil(try fetch(transaction).categoryID)

        try service.revert(batchID: batch.id)
        let restored = try fetch(transaction)
        XCTAssertEqual(restored.resolvedKind, .expense)
        XCTAssertEqual(restored.categoryID, groceriesID)
        XCTAssertEqual(restored.amount, Decimal(-12.5))
    }

    func testUndoOfOlderBatchIsRefusedWhileANewerOneTouchesTheSameMovement() throws {
        let transaction = try makeExpense("MERCADONA", merchant: "Mercadona")
        let first = try service.applyCategories(
            [CorrectionRequest(transactionID: transaction.id, categoryID: groceriesID)],
            action: .approve, propagateToMatches: false, rulePolicy: .none, createRules: false
        )
        let second = try service.applyCategories(
            [CorrectionRequest(transactionID: transaction.id, categoryID: leisureID)],
            action: .reassign, propagateToMatches: false, rulePolicy: .none, createRules: false
        )

        XCTAssertThrowsError(try service.revert(batchID: first.id)) { error in
            XCTAssertEqual(error as? CorrectionBatchError, .conflictingLaterChanges)
        }
        XCTAssertEqual(try fetch(transaction).categoryID, leisureID)

        try service.revert(batchID: second.id)
        try service.revert(batchID: first.id)
        XCTAssertNil(try fetch(transaction).categoryID)
        XCTAssertTrue(try fetch(transaction).needsReview)
    }

    func testViewModelUndoRestoresAndReselectsMovement() throws {
        let transaction = try makeExpense("MERCADONA", merchant: "Mercadona")
        let viewModel = ReviewQueueViewModel()
        viewModel.load(using: container)
        viewModel.select(try XCTUnwrap(viewModel.transactions.first))
        viewModel.selectedCategoryID = groceriesID
        viewModel.approveSelected(using: container)
        XCTAssertTrue(viewModel.transactions.isEmpty)

        viewModel.undoLast(using: container)

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.lastBatch)
        XCTAssertEqual(viewModel.transactions.map(\.id), [transaction.id])
        XCTAssertEqual(viewModel.selectedTransaction?.id, transaction.id)
    }

    // MARK: Atomicity

    func testFailedSaveLeavesNoPartialChanges() throws {
        let first = try makeExpense("NETFLIX", merchant: "Netflix")
        let second = try makeExpense("SPOTIFY", merchant: "Spotify")
        let sibling = try makeExpense("NETFLIX", merchant: "Netflix")
        service.failBeforeSaveForTesting = true

        XCTAssertThrowsError(try service.applyCategories(
            [
                CorrectionRequest(transactionID: first.id, categoryID: leisureID),
                CorrectionRequest(transactionID: second.id, categoryID: leisureID)
            ],
            action: .acceptHighConfidence,
            propagateToMatches: true,
            rulePolicy: .explicit,
            createRules: true
        ))

        for transaction in [first, second, sibling] {
            XCTAssertNil(try fetch(transaction).categoryID)
            XCTAssertTrue(try fetch(transaction).needsReview)
        }
        XCTAssertTrue(try container.correctionRepository.fetchAll().isEmpty)
        XCTAssertTrue(try container.ruleRepository.fetchAll().filter(\.createdFromUserCorrection).isEmpty)
        XCTAssertNil(try container.merchantRepository.preferredCategoryID(for: "Netflix"))
        XCTAssertTrue(service.history.isEmpty)
    }

    func testAcceptAllHighConfidenceSuggestionsIsOneUndoableBatch() throws {
        let a = try makeExpense("NETFLIX", merchant: "Netflix")
        let b = try makeExpense("SPOTIFY", merchant: "Spotify")
        for transaction in [a, b] {
            try container.transactionRepository.saveRecategorizationSuggestion(
                transactionID: transaction.id,
                categoryID: leisureID,
                source: .localML,
                confidence: 0.95,
                reason: "test"
            )
        }

        let viewModel = ReviewQueueViewModel()
        viewModel.load(using: container)
        viewModel.acceptAllHighConfidenceSuggestions(using: container)

        XCTAssertEqual(service.history.count, 1)
        XCTAssertEqual(viewModel.lastBatch?.explicitCount, 2)
        XCTAssertEqual(try fetch(a).categoryID, leisureID)

        viewModel.undoLast(using: container)
        XCTAssertNil(try fetch(a).categoryID)
        XCTAssertNil(try fetch(b).categoryID)
        XCTAssertEqual(try fetch(a).suggestedCategoryID, leisureID, "Undo must also bring the suggestion back")
    }

    // MARK: Rules

    func testReviewQueueSuggestsRuleInsteadOfCreatingIt() throws {
        let transaction = try makeExpense("NETFLIX", merchant: "Netflix", categoryID: leisureID, source: .localML, confidence: 0.85)

        let batch = try service.applyCategories(
            [CorrectionRequest(transactionID: transaction.id, categoryID: leisureID)],
            action: .approve,
            propagateToMatches: false,
            rulePolicy: .explicit,
            createRules: false
        )
        XCTAssertTrue(batch.hasRuleSuggestion)
        XCTAssertTrue(try container.ruleRepository.fetchAll().isEmpty)

        let ruleBatch = try XCTUnwrap(try service.createSuggestedRule(from: batch))
        XCTAssertEqual(try container.ruleRepository.fetchAll().count, 1)

        try service.revert(batchID: ruleBatch.id)
        XCTAssertTrue(try container.ruleRepository.fetchAll().isEmpty)
        XCTAssertEqual(try fetch(transaction).categoryID, leisureID, "Undoing the rule keeps the approval")
    }

    func testLegacyCorrectionStillPropagatesAndSuggestsRules() throws {
        let transaction = try makeExpense("NETFLIX", merchant: "Netflix", categoryID: leisureID, source: .localML, confidence: 0.85)
        let sibling = try makeExpense("NETFLIX", merchant: "Netflix")

        let count = try container.correctionLearningService.applyCorrection(
            for: transaction,
            categoryID: leisureID,
            applyToFuture: false
        )

        XCTAssertEqual(count, 2)
        XCTAssertEqual(try fetch(sibling).categoryID, leisureID)
        XCTAssertEqual(try container.ruleRepository.fetchAll().count, 1)
    }

    // MARK: Review findings

    func testLegacyCorrectionsDoNotEvictReviewUndoHistory() throws {
        let reviewed = try makeExpense("MERCADONA", merchant: "Mercadona")
        let reviewBatch = try service.applyCategories(
            [CorrectionRequest(transactionID: reviewed.id, categoryID: groceriesID)],
            action: .approve, propagateToMatches: false, rulePolicy: .none, createRules: false
        )
        for index in 0..<(CorrectionBatchService.historyLimit + 5) {
            let other = try makeExpense("TIENDA \(index)")
            try container.correctionLearningService.applyCorrection(for: other, categoryID: leisureID, applyToFuture: false)
        }

        XCTAssertEqual(service.history.map(\.id), [reviewBatch.id])
        XCTAssertNoThrow(try service.revert(batchID: reviewBatch.id))
    }

    func testRevertRefusesWhenAMovementNoLongerExists() throws {
        let kept = try makeExpense("NETFLIX", merchant: "Netflix")
        let deleted = try makeExpense("SPOTIFY", merchant: "Spotify")
        let batch = try service.applyCategories(
            [
                CorrectionRequest(transactionID: kept.id, categoryID: leisureID),
                CorrectionRequest(transactionID: deleted.id, categoryID: leisureID)
            ],
            action: .acceptHighConfidence, propagateToMatches: false, rulePolicy: .none, createRules: false
        )
        let context = ModelContext(container.modelContainer)
        let deletedID = deleted.id
        for transaction in try context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == deletedID })) {
            context.delete(transaction)
        }
        try context.save()

        XCTAssertThrowsError(try service.revert(batchID: batch.id)) { error in
            XCTAssertEqual(error as? CorrectionBatchError, .transactionNotFound)
        }
        XCTAssertEqual(try fetch(kept).categoryID, leisureID, "A refused undo must not partially restore")
        XCTAssertFalse(service.isReverted(batch.id))
    }

    func testAcceptingConfidentSuggestionOffersRule() throws {
        let transaction = try makeExpense("NETFLIX", merchant: "Netflix")
        try container.transactionRepository.saveRecategorizationSuggestion(
            transactionID: transaction.id, categoryID: leisureID, source: .localML, confidence: 0.9, reason: "test"
        )
        let batch = try service.applyCategories(
            [CorrectionRequest(transactionID: transaction.id, categoryID: leisureID)],
            action: .acceptSuggestion, propagateToMatches: false, rulePolicy: .explicit, createRules: false
        )
        XCTAssertTrue(batch.hasRuleSuggestion)
        XCTAssertTrue(try container.ruleRepository.fetchAll().isEmpty)
    }

    func testApplyToSimilarPreviewSkipsIncompatibleMovements() throws {
        let expense = try makeExpense("NETFLIX", merchant: "Netflix")
        let refund = Transaction(
            bookingDate: .now,
            rawDescription: "NETFLIX",
            cleanedDescription: "NETFLIX",
            amount: Decimal(12.5),
            kindRaw: TransactionKind.income.rawValue,
            fingerprint: "refund"
        )
        try container.transactionRepository.insert(refund)

        let ids = try service.compatibleTransactionIDs([expense.id, refund.id], categoryID: leisureID)
        XCTAssertEqual(ids, [expense.id])
    }
}

extension CorrectionBatchError: Equatable {}
