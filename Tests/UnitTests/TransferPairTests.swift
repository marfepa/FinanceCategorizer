import XCTest
import SwiftData
#if os(macOS)
@testable import FinanceCategorizerMac
#else
@testable import FinanceCategorizerIOS
#endif

@MainActor
final class TransferPairTests: XCTestCase {
    private let detector = TransferPairDetector()
    private let day: TimeInterval = 86_400
    private let base = Date(timeIntervalSince1970: 1_790_000_000)

    private func candidate(
        _ amount: Decimal,
        account: String?,
        daysOffset: Double = 0,
        batch: UUID? = UUID(),
        description: String? = nil,
        currency: String = "EUR",
        eligible: Bool = true
    ) -> TransferPairCandidate {
        TransferPairCandidate(
            id: UUID(),
            bookingDate: base.addingTimeInterval(daysOffset * day),
            amount: amount,
            currencyCode: currency,
            accountName: account,
            importBatchID: batch,
            description: description ?? (amount < 0 ? "TRANSFERENCIA EMITIDA" : "TRANSFERENCIA RECIBIDA"),
            isEligible: eligible
        )
    }

    // MARK: Detector

    func testPairsOppositeAmountsInDifferentAccountsWithinThreeDays() {
        let out = candidate(-500, account: "Openbank")
        let inc = candidate(500, account: "Cajamar", daysOffset: 2)

        let proposals = detector.detect(in: [out, inc])

        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals.first?.outgoing.id, out.id)
        XCTAssertEqual(proposals.first?.incoming.id, inc.id)
        XCTAssertEqual(proposals.first?.dayGap, 2)
        XCTAssertTrue(proposals.first?.hasNamedAccounts ?? false)
    }

    func testAmbiguousCounterpartsAreNotProposed() {
        let out = candidate(-500, account: "Openbank")
        let incA = candidate(500, account: "Cajamar", daysOffset: 1)
        let incB = candidate(500, account: "Abanca", daysOffset: 2)

        XCTAssertTrue(detector.detect(in: [out, incA, incB]).isEmpty)
    }

    func testNeverPairsSameAccountDifferentAmountsOrDistantDates() {
        XCTAssertTrue(detector.detect(in: [candidate(-500, account: "Openbank"), candidate(500, account: "openbank ")]).isEmpty)
        XCTAssertTrue(detector.detect(in: [candidate(-500, account: "Openbank"), candidate(499.99, account: "Cajamar")]).isEmpty)
        XCTAssertTrue(detector.detect(in: [candidate(-500, account: "Openbank"), candidate(500, account: "Cajamar", daysOffset: 4)]).isEmpty)
    }

    func testDifferentCurrenciesNeverPair() {
        XCTAssertTrue(detector.detect(in: [
            candidate(-500, account: "Openbank", currency: "EUR"),
            candidate(500, account: "Revolut", daysOffset: 1, currency: "USD")
        ]).isEmpty)
    }

    func testPurchaseAndRefundWithSameDescriptionAreNotATransfer() {
        XCTAssertTrue(detector.detect(in: [
            candidate(-49.99, account: "Tarjeta", description: "AMAZON EU"),
            candidate(49.99, account: "Openbank", daysOffset: 2, description: "amazon  eu")
        ]).isEmpty)
    }

    func testDayWindowUsesCalendarDaysAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Madrid"))
        // 2026-10-25 is the autumn DST change in Spain: 3 calendar days = 73 hours.
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 23)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26)))
        XCTAssertGreaterThan(end.timeIntervalSince(start), 3 * day)
        XCTAssertEqual(TransferPairDetector.calendarDayGap(start, end, calendar: calendar), 3)
    }

    func testIneligibleMovementsAreIgnored() {
        let out = candidate(-500, account: "Openbank", eligible: false)
        let inc = candidate(500, account: "Cajamar")
        XCTAssertTrue(detector.detect(in: [out, inc]).isEmpty)
    }

    func testUnnamedAccountsPairOnlyAcrossImportsWithLowerConfidence() {
        let sharedBatch = UUID()
        XCTAssertTrue(detector.detect(in: [
            candidate(-80, account: nil, batch: sharedBatch),
            candidate(80, account: nil, batch: sharedBatch)
        ]).isEmpty)

        // Without account names a transfer keyword is required.
        XCTAssertTrue(detector.detect(in: [
            candidate(-80, account: nil, description: "PAGO"),
            candidate(80, account: nil, daysOffset: 1, description: "ABONO")
        ]).isEmpty)

        let named = detector.detect(in: [candidate(-80, account: "A"), candidate(80, account: "B", daysOffset: 1)])
        let unnamed = detector.detect(in: [candidate(-80, account: nil), candidate(80, account: nil, daysOffset: 1)])
        XCTAssertEqual(unnamed.count, 1)
        XCTAssertFalse(unnamed[0].hasNamedAccounts)
        XCTAssertLessThan(unnamed[0].confidence, named[0].confidence)
    }

    func testDetectionIsFastOnFiveThousandMovements() {
        let accounts = ["Openbank", "Cajamar", "Abanca"]
        let candidates = (0..<5_000).map { index in
            candidate(
                Decimal(index % 700 + 1) * (index.isMultiple(of: 2) ? -1 : 1),
                account: accounts[index % accounts.count],
                daysOffset: Double(index % 365)
            )
        }
        let start = Date()
        _ = detector.detect(in: candidates)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.2)
    }

    // MARK: Service, undo and reporting

    private func insert(_ container: AppContainer, amount: Decimal, account: String, daysAgo: Double, source: CategorizationSource = .rule) throws -> Transaction {
        let transaction = Transaction(
            bookingDate: Date.now.addingTimeInterval(-daysAgo * day),
            rawDescription: amount < 0 ? "TRANSFERENCIA A MARIO" : "TRANSFERENCIA DE MARIO",
            cleanedDescription: amount < 0 ? "TRANSFERENCIA A MARIO" : "TRANSFERENCIA DE MARIO",
            amount: amount,
            kindRaw: (amount < 0 ? TransactionKind.expense : TransactionKind.income).rawValue,
            accountName: account,
            categorizationSourceRaw: source.rawValue,
            confidence: 0.8,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            fingerprint: UUID().uuidString
        )
        try container.transactionRepository.insert(transaction)
        return transaction
    }

    func testConfirmMarksBothAsTransferAndUndoRestoresThem() throws {
        let container = AppContainer(inMemory: true)
        let out = try insert(container, amount: -500, account: "Openbank", daysAgo: 2)
        let inc = try insert(container, amount: 500, account: "Cajamar", daysAgo: 0)

        let proposal = try XCTUnwrap(container.transferPairService.proposals().first)
        let batch = try container.transferPairService.confirm(proposal)

        XCTAssertEqual(batch.explicitCount, 2)
        XCTAssertEqual(try container.transactionRepository.fetch(transactionID: out.id)?.resolvedKind, .transfer)
        XCTAssertEqual(try container.transactionRepository.fetch(transactionID: inc.id)?.resolvedKind, .transfer)
        XCTAssertTrue(try container.transferPairService.proposals().isEmpty)

        try container.correctionBatchService.revert(batchID: batch.id)

        XCTAssertEqual(try container.transactionRepository.fetch(transactionID: out.id)?.resolvedKind, .expense)
        XCTAssertEqual(try container.transactionRepository.fetch(transactionID: inc.id)?.resolvedKind, .income)
        XCTAssertEqual(try container.transferPairService.proposals().count, 1)
    }

    func testManualDecisionsAreNeverProposed() throws {
        let container = AppContainer(inMemory: true)
        _ = try insert(container, amount: -500, account: "Openbank", daysAgo: 1, source: .manual)
        _ = try insert(container, amount: 500, account: "Cajamar", daysAgo: 0)
        XCTAssertTrue(try container.transferPairService.proposals().isEmpty)
    }

    func testConfirmRefusesWhenAMovementWasDecidedManuallySinceTheProposal() throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let out = try insert(container, amount: -300, account: "Openbank", daysAgo: 1)
        _ = try insert(container, amount: 300, account: "Cajamar", daysAgo: 0)
        let proposal = try XCTUnwrap(container.transferPairService.proposals().first)

        let groceries = try XCTUnwrap(container.categoryRepository.fetchAll().first { $0.name == "Alimentacion" })
        try container.correctionBatchService.applyCategories(
            [CorrectionRequest(transactionID: out.id, categoryID: groceries.id)],
            action: .reassign, propagateToMatches: false, rulePolicy: .none, createRules: false
        )

        XCTAssertThrowsError(try container.transferPairService.confirm(proposal)) { error in
            XCTAssertEqual(error as? CorrectionBatchError, .transferPairNoLongerValid)
        }
        XCTAssertEqual(try container.transactionRepository.fetch(transactionID: out.id)?.categoryID, groceries.id)
    }

    func testDismissHidesProposalForTheSession() throws {
        let container = AppContainer(inMemory: true)
        _ = try insert(container, amount: -60, account: "Openbank", daysAgo: 1)
        _ = try insert(container, amount: 60, account: "Cajamar", daysAgo: 0)

        let proposal = try XCTUnwrap(container.transferPairService.proposals().first)
        container.transferPairService.dismiss(proposal)
        XCTAssertTrue(try container.transferPairService.proposals().isEmpty)
    }

    func testConfirmedPairNoLongerInflatesIncomeAndSpending() throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        _ = try insert(container, amount: -500, account: "Openbank", daysAgo: 1)
        _ = try insert(container, amount: 500, account: "Cajamar", daysAgo: 0)
        let categories = try container.categoryRepository.fetchAll()
        let service = FinancialAnalysisService()

        let before = service.analyze(transactions: try container.transactionRepository.fetchAll(), categories: categories, range: .all)
        let proposal = try XCTUnwrap(container.transferPairService.proposals().first)
        try container.transferPairService.confirm(proposal)
        let after = service.analyze(transactions: try container.transactionRepository.fetchAll(), categories: categories, range: .all)

        XCTAssertEqual(before.totalIncome - after.totalIncome, 500)
        XCTAssertEqual(abs(before.totalExpenses) - abs(after.totalExpenses), 500)
    }

    func testReviewQueueConfirmShowsUndoBanner() throws {
        let container = AppContainer(inMemory: true)
        _ = try insert(container, amount: -75, account: "Openbank", daysAgo: 1)
        _ = try insert(container, amount: 75, account: "Cajamar", daysAgo: 0)

        let viewModel = ReviewQueueViewModel()
        viewModel.load(using: container)
        let proposal = try XCTUnwrap(viewModel.transferPairs.first)
        viewModel.confirmTransferPair(proposal, using: container)

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.transferPairs.isEmpty)
        XCTAssertEqual(viewModel.lastBatch?.action, .confirmTransferPair)

        viewModel.undoLast(using: container)
        XCTAssertEqual(viewModel.transferPairs.count, 1)
    }
}
