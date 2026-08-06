import Foundation

struct TransactionSnapshot: Sendable {
    let id: UUID
    let importBatchID: UUID?
    let externalID: String?
    let bookingDate: Date
    let valueDate: Date?
    let rawDescription: String
    let cleanedDescription: String
    let merchantDisplayName: String?
    let merchantCanonicalName: String?
    let amount: Decimal
    let balanceAfter: Decimal?
    let currencyCode: String
    let kindRaw: String?
    let accountName: String?
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
    let fingerprint: String
    let isRecurringCandidate: Bool
    let recurrenceGroupID: String?
    let duplicateGroupID: String?
    let duplicateReviewStatusRaw: String?
    let duplicateConfidence: Double?
    let duplicateReasonKey: String?
    let duplicateRecommendedKeepID: UUID?
    let createdAt: Date
    let updatedAt: Date

    init(from model: Transaction) {
        self.id = model.id
        self.importBatchID = model.importBatchID
        self.externalID = model.externalID
        self.bookingDate = model.bookingDate
        self.valueDate = model.valueDate
        self.rawDescription = model.rawDescription
        self.cleanedDescription = model.cleanedDescription
        self.merchantDisplayName = model.merchantDisplayName
        self.merchantCanonicalName = model.merchantCanonicalName
        self.amount = model.amount
        self.balanceAfter = model.balanceAfter
        self.currencyCode = model.currencyCode
        self.kindRaw = model.kindRaw
        self.accountName = model.accountName
        self.categoryID = model.categoryID
        self.subcategoryID = model.subcategoryID
        self.suggestedCategoryID = model.suggestedCategoryID
        self.suggestedSubcategoryID = model.suggestedSubcategoryID
        self.suggestedConfidence = model.suggestedConfidence
        self.suggestedSourceRaw = model.suggestedSourceRaw
        self.suggestedReason = model.suggestedReason
        self.categorizationSourceRaw = model.categorizationSourceRaw
        self.confidence = model.confidence
        self.needsReview = model.needsReview
        self.reviewStatusRaw = model.reviewStatusRaw
        self.categorizationReason = model.categorizationReason
        self.fingerprint = model.fingerprint
        self.isRecurringCandidate = model.isRecurringCandidate
        self.recurrenceGroupID = model.recurrenceGroupID
        self.duplicateGroupID = model.duplicateGroupID
        self.duplicateReviewStatusRaw = model.duplicateReviewStatusRaw
        self.duplicateConfidence = model.duplicateConfidence
        self.duplicateReasonKey = model.duplicateReasonKey
        self.duplicateRecommendedKeepID = model.duplicateRecommendedKeepID
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }

    func toModel() -> Transaction {
        Transaction(
            id: id,
            importBatchID: importBatchID,
            externalID: externalID,
            bookingDate: bookingDate,
            valueDate: valueDate,
            rawDescription: rawDescription,
            cleanedDescription: cleanedDescription,
            merchantDisplayName: merchantDisplayName,
            merchantCanonicalName: merchantCanonicalName,
            amount: amount,
            balanceAfter: balanceAfter,
            currencyCode: currencyCode,
            kindRaw: kindRaw,
            accountName: accountName,
            categoryID: categoryID,
            subcategoryID: subcategoryID,
            suggestedCategoryID: suggestedCategoryID,
            suggestedSubcategoryID: suggestedSubcategoryID,
            suggestedConfidence: suggestedConfidence,
            suggestedSourceRaw: suggestedSourceRaw,
            suggestedReason: suggestedReason,
            categorizationSourceRaw: categorizationSourceRaw,
            confidence: confidence,
            needsReview: needsReview,
            reviewStatusRaw: reviewStatusRaw,
            categorizationReason: categorizationReason,
            fingerprint: fingerprint,
            isRecurringCandidate: isRecurringCandidate,
            recurrenceGroupID: recurrenceGroupID,
            duplicateGroupID: duplicateGroupID,
            duplicateReviewStatusRaw: duplicateReviewStatusRaw,
            duplicateConfidence: duplicateConfidence,
            duplicateReasonKey: duplicateReasonKey,
            duplicateRecommendedKeepID: duplicateRecommendedKeepID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    var resolvedKind: TransactionKind {
        if let raw = kindRaw, let kind = TransactionKind(rawValue: raw) {
            return kind
        }
        return amount >= 0 ? .income : .expense
    }
}

struct CategorySnapshot: Sendable {
    let id: UUID
    let name: String
    let iconName: String
    let colorHex: String
    let parentID: UUID?
    let isIncome: Bool
    let sortOrder: Int
    let isSystem: Bool

    init(from model: Category) {
        self.id = model.id
        self.name = model.name
        self.iconName = model.iconName
        self.colorHex = model.colorHex
        self.parentID = model.parentID
        self.isIncome = model.isIncome
        self.sortOrder = model.sortOrder
        self.isSystem = model.isSystem
    }

    func toModel() -> Category {
        Category(
            id: id,
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            parentID: parentID,
            isIncome: isIncome,
            sortOrder: sortOrder,
            isSystem: isSystem
        )
    }
}

struct AccountSnapshot: Sendable {
    let id: UUID
    let name: String
    let institution: String?
    let currencyCode: String
    let currentBalance: Decimal?
    let balanceAsOf: Date?
    let balanceSourceRaw: String?
    let isLiability: Bool
    let createdAt: Date

    init(from model: Account) {
        self.id = model.id
        self.name = model.name
        self.institution = model.institution
        self.currencyCode = model.currencyCode
        self.currentBalance = model.currentBalance
        self.balanceAsOf = model.balanceAsOf
        self.balanceSourceRaw = model.balanceSourceRaw
        self.isLiability = model.isLiability
        self.createdAt = model.createdAt
    }

    func toModel() -> Account {
        Account(
            id: id,
            name: name,
            institution: institution,
            currencyCode: currencyCode,
            currentBalance: currentBalance,
            balanceAsOf: balanceAsOf,
            balanceSourceRaw: balanceSourceRaw,
            isLiability: isLiability,
            createdAt: createdAt
        )
    }
}

struct SavingsGoalSnapshot: Sendable {
    let id: UUID
    let name: String
    let kindRaw: String
    let targetAmount: Decimal
    let allocatedAmount: Decimal
    let monthlyContribution: Decimal
    let targetDate: Date?
    let isActive: Bool
    let createdAt: Date

    init(from model: SavingsGoal) {
        self.id = model.id
        self.name = model.name
        self.kindRaw = model.kindRaw
        self.targetAmount = model.targetAmount
        self.allocatedAmount = model.allocatedAmount
        self.monthlyContribution = model.monthlyContribution
        self.targetDate = model.targetDate
        self.isActive = model.isActive
        self.createdAt = model.createdAt
    }

    func toModel() -> SavingsGoal {
        let kind = SavingsGoalKind(rawValue: kindRaw) ?? .other
        return SavingsGoal(
            id: id,
            name: name,
            kind: kind,
            targetAmount: targetAmount,
            allocatedAmount: allocatedAmount,
            monthlyContribution: monthlyContribution,
            targetDate: targetDate,
            isActive: isActive,
            createdAt: createdAt
        )
    }
}

struct ImportBatchSnapshot: Sendable {
    let id: UUID
    let fileName: String
    let sourceType: String
    let importedAt: Date
    let rawRowCount: Int
    let validRowCount: Int
    let importedRowCount: Int
    let duplicatesSkipped: Int
    let pendingReviewCount: Int
    let fileFingerprint: String?
    let rowFingerprint: String?
    let dateRangeText: String?

    init(from model: ImportBatch) {
        self.id = model.id
        self.fileName = model.fileName
        self.sourceType = model.sourceType
        self.importedAt = model.importedAt
        self.rawRowCount = model.rawRowCount
        self.validRowCount = model.validRowCount
        self.importedRowCount = model.importedRowCount
        self.duplicatesSkipped = model.duplicatesSkipped
        self.pendingReviewCount = model.pendingReviewCount
        self.fileFingerprint = model.fileFingerprint
        self.rowFingerprint = model.rowFingerprint
        self.dateRangeText = model.dateRangeText
    }

    func toModel() -> ImportBatch {
        ImportBatch(
            id: id,
            fileName: fileName,
            sourceType: sourceType,
            importedAt: importedAt,
            rawRowCount: rawRowCount,
            validRowCount: validRowCount,
            importedRowCount: importedRowCount,
            duplicatesSkipped: duplicatesSkipped,
            pendingReviewCount: pendingReviewCount,
            fileFingerprint: fileFingerprint,
            rowFingerprint: rowFingerprint,
            dateRangeText: dateRangeText
        )
    }
}
