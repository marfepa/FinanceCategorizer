import XCTest

#if os(macOS)
@testable import FinanceCategorizerMac
#else
@testable import FinanceCategorizerIOS
#endif

final class FinancialAnalysisRecurringExpensesTests: XCTestCase {
    func testAnalysisUsesFullHistoryToDetectRecurringExpenseOutsideSelectedRange() {
        let category = Category(
            name: "Suscripciones",
            iconName: "repeat",
            colorHex: "#5E35B1"
        )
        let transactions = (1...6).map { month in
            Transaction(
                bookingDate: date(year: 2026, month: month, day: 7),
                rawDescription: "STREAMING (month)",
                cleanedDescription: "STREAMING (month)",
                merchantCanonicalName: "Streaming",
                amount: Decimal(string: "-14.99")!,
                kindRaw: TransactionKind.expense.rawValue,
                categoryID: category.id,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            )
        }

        let snapshot = FinancialAnalysisService().analyze(
            transactions: transactions,
            categories: [category],
            range: .month,
            now: date(year: 2026, month: 6, day: 20)
        )

        XCTAssertEqual(snapshot.recurringExpenses.count, 1)
        XCTAssertEqual(snapshot.recurringExpenses.first?.occurrences, 6)
        XCTAssertEqual(snapshot.recurringExpenses.first?.expectedMonths, 6)
        XCTAssertEqual(snapshot.recurringExpenses.first?.categoryName, "Suscripciones")
        XCTAssertEqual(snapshot.recurringMonthlyExpenses, Decimal(string: "14.99")!)
    }

    func testAnalysisDoesNotCountPendingDuplicateAsAnotherRecurringMonth() {
        let recurring = (1...3).map { month in
            Transaction(
                bookingDate: date(year: 2026, month: month, day: 5),
                rawDescription: "SEGURO",
                cleanedDescription: "SEGURO",
                merchantCanonicalName: "Seguro",
                amount: Decimal(-40),
                kindRaw: TransactionKind.expense.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            )
        }
        let duplicate = Transaction(
            bookingDate: date(year: 2026, month: 3, day: 6),
            rawDescription: "SEGURO",
            cleanedDescription: "SEGURO",
            merchantCanonicalName: "Seguro",
            amount: Decimal(-40),
            kindRaw: TransactionKind.expense.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            duplicateReviewStatusRaw: DuplicateReviewStatus.pending.rawValue
        )

        let snapshot = FinancialAnalysisService().analyze(
            transactions: recurring + [duplicate],
            categories: [],
            range: .all,
            now: date(year: 2026, month: 3, day: 20)
        )

        XCTAssertEqual(snapshot.recurringExpenses.first?.occurrences, 3)
        XCTAssertEqual(snapshot.recurringExpenses.first?.transactionIDs.count, 3)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date!
    }
}
