import XCTest
#if os(macOS)
@testable import FinanceCategorizerMac
private typealias AppCategory = FinanceCategorizerMac.Category
#else
@testable import FinanceCategorizerIOS
private typealias AppCategory = FinanceCategorizerIOS.Category
#endif

@MainActor
final class SavingsStrategyServiceTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testDefaultBucketsFollowFiftyThirtyTwentyReading() {
        XCTAssertEqual(SavingsAllocationBucket.defaultBucket(forCategoryNamed: "Hogar", isIncome: false), .needs)
        XCTAssertEqual(SavingsAllocationBucket.defaultBucket(forCategoryNamed: "Suministros", isIncome: false), .needs)
        XCTAssertEqual(SavingsAllocationBucket.defaultBucket(forCategoryNamed: "Restauracion", isIncome: false), .wants)
        XCTAssertEqual(SavingsAllocationBucket.defaultBucket(forCategoryNamed: "Compras", isIncome: false), .wants)
        XCTAssertEqual(SavingsAllocationBucket.defaultBucket(forCategoryNamed: "Inversión", isIncome: false), .investment)
        XCTAssertEqual(SavingsAllocationBucket.defaultBucket(forCategoryNamed: "Finanzas", isIncome: false), .needs)
        XCTAssertNil(SavingsAllocationBucket.defaultBucket(forCategoryNamed: "Ingresos", isIncome: true))
        XCTAssertNil(SavingsAllocationBucket.defaultBucket(forCategoryNamed: "Transferencias", isIncome: false))
        XCTAssertEqual(SavingsAllocationBucket.inferred(from: "RECIBO HIPOTECA OPENBANK"), .needs)
        XCTAssertEqual(SavingsAllocationBucket.inferred(from: "AMAZON EU SARL"), .wants)
        XCTAssertEqual(SavingsAllocationBucket.inferred(from: "INDEXA CAPITAL"), .investment)
    }

    func testBalancedMonthStaysWithinFiftyThirtyTwenty() {
        let snapshot = makeSnapshot(
            income: 2000,
            rent: 900,
            restaurants: 500,
            extraInvestment: 0
        )

        XCTAssertEqual(snapshot.income, 2000)
        XCTAssertEqual(snapshot.result(for: .needs)?.actualAmount, 900)
        XCTAssertEqual(snapshot.result(for: .wants)?.actualAmount, 500)
        XCTAssertEqual(snapshot.result(for: .investment)?.actualAmount, 600)
        XCTAssertEqual(snapshot.result(for: .investment)?.residualAmount, 600)
        XCTAssertEqual(snapshot.result(for: .needs)?.status, .within)
        XCTAssertEqual(snapshot.result(for: .wants)?.status, .within)
        XCTAssertEqual(snapshot.result(for: .investment)?.status, .within)
        XCTAssertTrue(snapshot.isOnTrack)
    }

    func testWantsOverTargetMarksTheMonthOffRange() {
        let snapshot = makeSnapshot(
            income: 2000,
            rent: 900,
            restaurants: 800,
            extraInvestment: 0
        )

        XCTAssertEqual(snapshot.result(for: .wants)?.status, .over)
        XCTAssertEqual(snapshot.result(for: .investment)?.status, .under)
        XCTAssertFalse(snapshot.isOnTrack)
        XCTAssertEqual(snapshot.overallStatus, .over)
    }

    func testExplicitInvestmentAndResidualAreCombined() {
        let snapshot = makeSnapshot(
            income: 2000,
            rent: 800,
            restaurants: 400,
            extraInvestment: 200
        )

        let investment = snapshot.result(for: .investment)
        XCTAssertEqual(investment?.explicitAmount, 200)
        XCTAssertEqual(investment?.residualAmount, 600)
        XCTAssertEqual(investment?.actualAmount, 800)
        XCTAssertEqual(investment?.status, .within)
        XCTAssertTrue(snapshot.isOnTrack)
    }

    func testInternalTransfersAreIgnored() {
        let housing = category("Hogar")
        let income = category("Ingresos", isIncome: true)
        let transfers = category("Transferencias")
        let now = date(2026, 4, 20)
        let transactions = [
            transaction(date(2026, 4, 1), "NOMINA", 2000, .income, income.id),
            transaction(date(2026, 4, 3), "ALQUILER", -1000, .expense, housing.id),
            transaction(date(2026, 4, 4), "TRASPASO CUENTA PROPIA", -400, .transfer, transfers.id)
        ]

        let snapshot = SavingsStrategyService().buildSnapshot(
            transactions: transactions,
            categories: [housing, income, transfers],
            config: .default,
            monthStart: date(2026, 4, 1),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot?.income, 2000)
        XCTAssertEqual(snapshot?.result(for: .needs)?.actualAmount, 1000)
        XCTAssertEqual(snapshot?.result(for: .investment)?.actualAmount, 1000)
        XCTAssertEqual(snapshot?.unassignedAmount, 0)
    }

    func testCategoryOverrideMovesSpendingBetweenBuckets() {
        let shopping = category("Compras")
        let income = category("Ingresos", isIncome: true)
        var config = SavingsStrategyConfig.default
        config = config.assigning(shopping.id, to: .needs)

        let snapshot = SavingsStrategyService().buildSnapshot(
            transactions: [
                transaction(date(2026, 4, 1), "NOMINA", 1000, .income, income.id),
                transaction(date(2026, 4, 6), "ZARA", -200, .expense, shopping.id)
            ],
            categories: [shopping, income],
            config: config,
            monthStart: date(2026, 4, 1),
            now: date(2026, 4, 20),
            calendar: calendar
        )

        XCTAssertEqual(snapshot?.result(for: .needs)?.actualAmount, 200)
        XCTAssertEqual(snapshot?.result(for: .wants)?.actualAmount, 0)
    }

    func testUnassignedSpendingDoesNotInflateInvestment() {
        let unknown = category("Sin categorizar")
        let income = category("Ingresos", isIncome: true)
        let snapshot = SavingsStrategyService().buildSnapshot(
            transactions: [
                transaction(date(2026, 4, 1), "NOMINA", 1000, .income, income.id),
                transaction(date(2026, 4, 8), "PAGO GENERICO", -100, .expense, unknown.id)
            ],
            categories: [unknown, income],
            config: .default,
            monthStart: date(2026, 4, 1),
            now: date(2026, 4, 20),
            calendar: calendar
        )

        XCTAssertEqual(snapshot?.unassignedAmount, 100)
        XCTAssertEqual(snapshot?.result(for: .investment)?.actualAmount, 900)
        XCTAssertEqual(snapshot?.result(for: .investment)?.residualAmount, 900)
    }

    func testUncategorizedMortgageDescriptionFallsIntoFixedCosts() {
        let unknown = category("Sin categorizar")
        let income = category("Ingresos", isIncome: true)
        let snapshot = SavingsStrategyService().buildSnapshot(
            transactions: [
                transaction(date(2026, 4, 1), "NOMINA", 2000, .income, income.id),
                transaction(date(2026, 4, 3), "RECIBO HIPOTECA OPENBANK", -800, .expense, unknown.id)
            ],
            categories: [unknown, income],
            config: .default,
            monthStart: date(2026, 4, 1),
            now: date(2026, 4, 20),
            calendar: calendar
        )

        XCTAssertEqual(snapshot?.result(for: .needs)?.actualAmount, 800)
        XCTAssertEqual(snapshot?.unassignedAmount, 0)
    }

    func testAdjustingPercentagesKeepsAHundredTotal() {
        var config = SavingsStrategyConfig.default
        config = config.adjusting(bucket: .needs, delta: 1)
        XCTAssertEqual(config.needsPercent + config.wantsPercent + config.investmentPercent, 100)
        XCTAssertEqual(config.needsPercent, 51)
        XCTAssertEqual(config.preset, .custom)

        config = SavingsStrategyConfig.default.applying(preset: .seventyTwentyTen)
        XCTAssertEqual(config.needsPercent, 70)
        XCTAssertEqual(config.wantsPercent, 20)
        XCTAssertEqual(config.investmentPercent, 10)
        XCTAssertEqual(config.preset, .seventyTwentyTen)
    }

    func testStoreRoundTripsConfiguration() {
        let suiteName = "savings-strategy-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SavingsStrategyStore(defaults: defaults)
        var config = SavingsStrategyConfig.default.applying(preset: .sixtyTwentyTwenty)
        config.tolerancePercentPoints = 3
        store.save(config)

        let loaded = store.load()
        XCTAssertEqual(loaded.needsPercent, 60)
        XCTAssertEqual(loaded.wantsPercent, 20)
        XCTAssertEqual(loaded.investmentPercent, 20)
        XCTAssertEqual(loaded.tolerancePercentPoints, 3)
    }

    private func makeSnapshot(
        income: Decimal,
        rent: Decimal,
        restaurants: Decimal,
        extraInvestment: Decimal
    ) -> SavingsStrategySnapshot {
        let housing = category("Hogar")
        let dining = category("Restauracion")
        let investing = category("Inversión")
        let incomeCategory = category("Ingresos", isIncome: true)
        var transactions = [
            transaction(date(2026, 4, 1), "NOMINA", income, .income, incomeCategory.id),
            transaction(date(2026, 4, 2), "ALQUILER", -rent, .expense, housing.id),
            transaction(date(2026, 4, 5), "RESTAURANTE", -restaurants, .expense, dining.id)
        ]
        if extraInvestment > 0 {
            transactions.append(
                transaction(date(2026, 4, 7), "BROKER", -extraInvestment, .expense, investing.id)
            )
        }

        let snapshot = SavingsStrategyService().buildSnapshot(
            transactions: transactions,
            categories: [housing, dining, investing, incomeCategory],
            config: .default,
            monthStart: date(2026, 4, 1),
            now: date(2026, 4, 20),
            calendar: calendar
        )
        return snapshot!
    }

    private func category(_ name: String, isIncome: Bool = false) -> AppCategory {
        AppCategory(name: name, iconName: "tag", colorHex: "#000000", isIncome: isIncome)
    }

    private func transaction(
        _ date: Date,
        _ description: String,
        _ amount: Decimal,
        _ kind: TransactionKind,
        _ categoryID: UUID
    ) -> Transaction {
        Transaction(
            bookingDate: date,
            rawDescription: description,
            cleanedDescription: description,
            amount: amount,
            kindRaw: kind.rawValue,
            categoryID: categoryID,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? .now
    }
}
