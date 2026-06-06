import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var importBatchID: UUID?
    var externalID: String?
    var bookingDate: Date
    var valueDate: Date?
    var rawDescription: String
    var cleanedDescription: String
    var merchantDisplayName: String?
    var merchantCanonicalName: String?
    var amount: Decimal
    var currencyCode: String
    var kindRaw: String?
    var accountName: String?
    var categoryID: UUID?
    var subcategoryID: UUID?
    var categorizationSourceRaw: String
    var confidence: Double
    var needsReview: Bool
    var reviewStatusRaw: String
    var categorizationReason: String?
    var fingerprint: String
    var isRecurringCandidate: Bool
    var recurrenceGroupID: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        importBatchID: UUID? = nil,
        externalID: String? = nil,
        bookingDate: Date,
        valueDate: Date? = nil,
        rawDescription: String,
        cleanedDescription: String,
        merchantDisplayName: String? = nil,
        merchantCanonicalName: String? = nil,
        amount: Decimal,
        currencyCode: String = AppConfig.defaultCurrencyCode,
        kindRaw: String? = nil,
        accountName: String? = nil,
        categoryID: UUID? = nil,
        subcategoryID: UUID? = nil,
        categorizationSourceRaw: String = CategorizationSource.unknown.rawValue,
        confidence: Double = 0,
        needsReview: Bool = true,
        reviewStatusRaw: String = ReviewStatus.pending.rawValue,
        categorizationReason: String? = nil,
        fingerprint: String = "",
        isRecurringCandidate: Bool = false,
        recurrenceGroupID: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.importBatchID = importBatchID
        self.externalID = externalID
        self.bookingDate = bookingDate
        self.valueDate = valueDate
        self.rawDescription = rawDescription
        self.cleanedDescription = cleanedDescription
        self.merchantDisplayName = merchantDisplayName
        self.merchantCanonicalName = merchantCanonicalName
        self.amount = amount
        self.currencyCode = currencyCode
        self.kindRaw = kindRaw
        self.accountName = accountName
        self.categoryID = categoryID
        self.subcategoryID = subcategoryID
        self.categorizationSourceRaw = categorizationSourceRaw
        self.confidence = confidence
        self.needsReview = needsReview
        self.reviewStatusRaw = reviewStatusRaw
        self.categorizationReason = categorizationReason
        self.fingerprint = fingerprint
        self.isRecurringCandidate = isRecurringCandidate
        self.recurrenceGroupID = recurrenceGroupID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Transaction {
    var resolvedKind: TransactionKind {
        if let raw = kindRaw, let kind = TransactionKind(rawValue: raw) {
            return kind
        }
        return amount >= 0 ? .income : .expense
    }

    /// The date used for accounting and reporting.
    /// Payroll (nómina) received from the configurable cutoff day onwards belongs to the following month's income.
    var accountingDate: Date {
        let cutoffDay = UserDefaults.standard.integer(forKey: "payrollCutoffDay")
        let effectiveCutoff = cutoffDay >= 22 ? cutoffDay : 25

        let isIncome = amount > 0 || resolvedKind == .income
        let isPayroll = cleanedDescription.lowercased().contains("nomina") ||
                        rawDescription.lowercased().contains("nómina") ||
                        rawDescription.lowercased().contains("nomina")

        if isIncome && isPayroll {
            let calendar = Calendar.current
            let day = calendar.component(.day, from: bookingDate)
            if day >= effectiveCutoff {
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: bookingDate),
                   let startOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) {
                    return startOfNextMonth
                }
            }
        }
        return bookingDate
    }
}
