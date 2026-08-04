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
    // Re-categorization proposals are kept apart from the accepted category
    // so an analysis run can never overwrite a user's previous decision.
    var suggestedCategoryID: UUID?
    var suggestedSubcategoryID: UUID?
    var suggestedConfidence: Double?
    var suggestedSourceRaw: String?
    var suggestedReason: String?
    var categorizationSourceRaw: String
    var confidence: Double
    var needsReview: Bool
    var reviewStatusRaw: String
    var categorizationReason: String?
    var fingerprint: String
    var isRecurringCandidate: Bool
    var recurrenceGroupID: String?
    var duplicateGroupID: String?
    var duplicateReviewStatusRaw: String?
    // Optional so existing SwiftData stores can add the audit metadata through
    // a lightweight migration without requiring a destructive store reset.
    var duplicateConfidence: Double?
    var duplicateReasonKey: String?
    var duplicateRecommendedKeepID: UUID?
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
        suggestedCategoryID: UUID? = nil,
        suggestedSubcategoryID: UUID? = nil,
        suggestedConfidence: Double? = nil,
        suggestedSourceRaw: String? = nil,
        suggestedReason: String? = nil,
        categorizationSourceRaw: String = CategorizationSource.unknown.rawValue,
        confidence: Double = 0,
        needsReview: Bool = true,
        reviewStatusRaw: String = ReviewStatus.pending.rawValue,
        categorizationReason: String? = nil,
        fingerprint: String = "",
        isRecurringCandidate: Bool = false,
        recurrenceGroupID: String? = nil,
        duplicateGroupID: String? = nil,
        duplicateReviewStatusRaw: String? = nil,
        duplicateConfidence: Double? = nil,
        duplicateReasonKey: String? = nil,
        duplicateRecommendedKeepID: UUID? = nil,
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
        self.suggestedCategoryID = suggestedCategoryID
        self.suggestedSubcategoryID = suggestedSubcategoryID
        self.suggestedConfidence = suggestedConfidence
        self.suggestedSourceRaw = suggestedSourceRaw
        self.suggestedReason = suggestedReason
        self.categorizationSourceRaw = categorizationSourceRaw
        self.confidence = confidence
        self.needsReview = needsReview
        self.reviewStatusRaw = reviewStatusRaw
        self.categorizationReason = categorizationReason
        self.fingerprint = fingerprint
        self.isRecurringCandidate = isRecurringCandidate
        self.recurrenceGroupID = recurrenceGroupID
        self.duplicateGroupID = duplicateGroupID
        self.duplicateReviewStatusRaw = duplicateReviewStatusRaw
        self.duplicateConfidence = duplicateConfidence
        self.duplicateReasonKey = duplicateReasonKey
        self.duplicateRecommendedKeepID = duplicateRecommendedKeepID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Transaction {
    var hasRecategorizationSuggestion: Bool {
        suggestedCategoryID != nil
    }

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
