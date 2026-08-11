import XCTest

#if os(macOS)
@testable import FinanceCategorizerMac
#else
@testable import FinanceCategorizerIOS
#endif

final class RecurringExpenseDetectorTests: XCTestCase {
    func testDetectsMonthlyExpenseAcrossDistinctMonths() {
        let entries = (1...6).map { month in
            entry(
                year: 2026,
                month: month,
                day: 5 + (month.isMultiple(of: 2) ? 2 : 0),
                description: "NETFLIX (month)",
                merchant: "Netflix",
                amount: -12.99
            )
        }

        let result = RecurringExpenseDetector(calendar: utcCalendar).detect(from: entries)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.occurrences, 6)
        XCTAssertEqual(result.first?.expectedMonths, 6)
        XCTAssertEqual(result.first?.monthlyCoverage, 1)
        XCTAssertEqual(result.first?.recurrenceType, .monthly)
        XCTAssertEqual(result.first?.status, .confirmed)
    }

    func testMissingMonthIsReportedInLongerSeries() {
        let entries = [1, 2, 4].map { month in
            entry(
                year: 2026,
                month: month,
                day: 5,
                description: "ALQUILER",
                merchant: "Alquiler",
                amount: -800
            )
        }

        let result = RecurringExpenseDetector(calendar: utcCalendar).detect(from: entries)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.occurrences, 3)
        XCTAssertEqual(result.first?.expectedMonths, 4)
        XCTAssertEqual(result.first?.missingMonths.count, 1)
    }

    func testTwoChargesInOneMonthCountAsOneOccurrence() {
        let entries = [
            entry(year: 2026, month: 1, day: 5, description: "STREAMING", merchant: "Streaming", amount: -10),
            entry(year: 2026, month: 2, day: 5, description: "STREAMING", merchant: "Streaming", amount: -10),
            entry(year: 2026, month: 2, day: 20, description: "STREAMING EXTRA", merchant: "Streaming", amount: -10),
            entry(year: 2026, month: 3, day: 5, description: "STREAMING", merchant: "Streaming", amount: -10)
        ]

        let result = RecurringExpenseDetector(calendar: utcCalendar).detect(from: entries)

        XCTAssertEqual(result.first?.occurrences, 3)
        XCTAssertEqual(result.first?.expectedMonths, 3)
    }

    func testDoesNotPromoteUnstableMerchantCharges() {
        let entries = [
            entry(year: 2026, month: 1, day: 3, description: "MERCADONA", merchant: "Mercadona", amount: -55),
            entry(year: 2026, month: 2, day: 14, description: "MERCADONA", merchant: "Mercadona", amount: -180),
            entry(year: 2026, month: 3, day: 25, description: "MERCADONA", merchant: "Mercadona", amount: -90)
        ]

        let result = RecurringExpenseDetector(calendar: utcCalendar).detect(from: entries)

        XCTAssertTrue(result.isEmpty)
    }

    func testUsesCanonicalMerchantWhenDescriptionsVary() {
        let entries = (1...3).map { month in
            entry(
                year: 2026,
                month: month,
                day: 8,
                description: "APPLE SERVICES REF (month)",
                merchant: "Apple Services",
                amount: -9.99
            )
        }

        let result = RecurringExpenseDetector(calendar: utcCalendar).detect(from: entries)

        XCTAssertEqual(result.first?.id, "APPLE SERVICES")
        XCTAssertEqual(result.first?.merchantName, "Apple Services")
    }

    func testExcludesPendingDuplicatesAndTransfers() {
        let recurring = (1...3).map { month in
            entry(year: 2026, month: month, day: 4, description: "SEGURO", merchant: "Seguro", amount: -40)
        }
        let pendingDuplicate = entry(
            year: 2026,
            month: 3,
            day: 4,
            description: "SEGURO",
            merchant: "Seguro",
            amount: -40,
            duplicateStatus: DuplicateReviewStatus.pending.rawValue
        )
        let transfer = entry(
            year: 2026,
            month: 3,
            day: 6,
            description: "TRANSFERENCIA",
            merchant: nil,
            amount: -40,
            kind: TransactionKind.transfer.rawValue
        )

        let result = RecurringExpenseDetector(calendar: utcCalendar).detect(from: recurring + [pendingDuplicate, transfer])

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.occurrences, 3)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func entry(
        year: Int,
        month: Int,
        day: Int,
        description: String,
        merchant: String?,
        amount: Decimal,
        kind: String? = TransactionKind.expense.rawValue,
        duplicateStatus: String? = nil
    ) -> FinancialReportingEntry {
        let date = utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
        let transaction = Transaction(
            bookingDate: date,
            rawDescription: description,
            cleanedDescription: description,
            merchantCanonicalName: merchant,
            amount: amount,
            kindRaw: kind,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            duplicateReviewStatusRaw: duplicateStatus
        )
        return FinancialReportingEntry(transaction: transaction, date: date, amount: amount)
    }
}
