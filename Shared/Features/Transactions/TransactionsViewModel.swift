import Foundation
import Observation

@MainActor
@Observable
final class TransactionsViewModel {
    enum TransactionDateSortOrder: String, CaseIterable, Hashable {
        case newestFirst
        case oldestFirst
    }

    var searchText = "" {
        didSet { recomputeFilteredResults() }
    }
    var transactions: [Transaction] = [] {
        didSet { recomputeFilteredResults() }
    }
    var selectedTransaction: Transaction?
    var categories: [Category] = []
    var selectedCategoryID: UUID?
    var selectedKind: TransactionKind = .expense
    var newCategoryName = ""
    var newCategoryIsIncome = false
    var batchRecategorizationKind: TransactionKind = .expense
    var isRecategorizing = false
    var recategorizationSummary: String?
    var statusMessage: String?
    var errorMessage: String?
    var duplicateGroups: [DuplicateMovementGroup] = []
    var isScanningDuplicates = false

    // Filters
    var filterStartDate: Date? {
        didSet { recomputeFilteredResults() }
    }
    var filterEndDate: Date? {
        didSet { recomputeFilteredResults() }
    }
    var filterCategoryID: UUID? {
        didSet { recomputeFilteredResults() }
    }
    var filterKind: TransactionKind? {
        didSet { recomputeFilteredResults() }
    }
    var transactionDateSortOrder: TransactionDateSortOrder = .newestFirst {
        didSet { recomputeFilteredResults() }
    }

    private(set) var sortedTransactions: [Transaction] = []
    private(set) var filteredIncome: Decimal = 0
    private(set) var filteredExpense: Decimal = 0
    private(set) var filteredCount: Int = 0

    var filteredTransactions: [Transaction] {
        sortedTransactions
    }

    func recomputeFilteredResults() {
        var result = transactions

        if let filterStartDate {
            result = result.filter { $0.bookingDate >= filterStartDate }
        }
        if let filterEndDate {
            result = result.filter { $0.bookingDate <= filterEndDate }
        }
        if let filterCategoryID {
            result = result.filter { $0.categoryID == filterCategoryID }
        }
        if let filterKind {
            result = result.filter { $0.resolvedKind == filterKind }
        }

        if !searchText.isEmpty {
            let query = searchText
            result = result.filter {
                $0.rawDescription.localizedCaseInsensitiveContains(query) ||
                $0.cleanedDescription.localizedCaseInsensitiveContains(query)
            }
        }

        switch transactionDateSortOrder {
        case .newestFirst:
            result.sort { $0.bookingDate > $1.bookingDate }
        case .oldestFirst:
            result.sort { $0.bookingDate < $1.bookingDate }
        }

        sortedTransactions = result

        var income: Decimal = 0
        var expense: Decimal = 0
        for tx in result {
            if tx.resolvedKind == .income {
                income += tx.amount
            } else if tx.resolvedKind == .expense {
                expense += tx.amount
            }
        }
        filteredIncome = income
        filteredExpense = expense
        filteredCount = result.count
    }


    func load(using container: AppContainer) {
        do {
            transactions = try container.transactionRepository.fetchAll()
            categories = try container.categoryRepository.fetchAll()
            duplicateGroups = pendingDuplicateGroups(from: transactions)
            if selectedTransaction == nil {
                selectedTransaction = transactions.first
            } else if let selectedTransaction,
                      !transactions.contains(where: { $0.id == selectedTransaction.id }) {
                self.selectedTransaction = transactions.first
            }
            selectedCategoryID = selectedTransaction?.categoryID
            selectedKind = selectedTransaction?.resolvedKind ?? .expense
            newCategoryIsIncome = selectedKind == .income
            if transactions.contains(where: { $0.resolvedKind == batchRecategorizationKind }) == false {
                batchRecategorizationKind = selectedKind
            }
            recategorizationSummary = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scanDuplicates(using container: AppContainer, language: AppLanguage = .currentSelection) {
        guard !isScanningDuplicates else { return }

        isScanningDuplicates = true
        defer { isScanningDuplicates = false }

        do {
            let allTransactions = try container.transactionRepository.fetchAll()
            let groups = container.duplicateAuditService.analyze(transactions: allTransactions)
            try container.transactionRepository.applyDuplicateAudit(groups)
            load(using: container)
            statusMessage = language.localized(
                "duplicate.status.scanned",
                language.formatInteger(duplicateGroups.count)
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissDuplicateGroup(_ group: DuplicateMovementGroup, using container: AppContainer, language: AppLanguage = .currentSelection) {
        do {
            try container.transactionRepository.dismissDuplicateGroup(groupID: group.id)
            load(using: container)
            statusMessage = language.localized("duplicate.status.dismissed")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeDuplicateGroup(_ group: DuplicateMovementGroup, using container: AppContainer, language: AppLanguage = .currentSelection) {
        do {
            try container.transactionRepository.deleteDuplicateGroup(
                groupID: group.id,
                keeping: group.recommendedKeepID
            )
            load(using: container)
            statusMessage = language.localized("duplicate.status.resolved")
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveAllDuplicateGroups(_ groups: [DuplicateMovementGroup], using container: AppContainer, language: AppLanguage = .currentSelection) {
        guard !groups.isEmpty else { return }

        do {
            try container.transactionRepository.resolveDuplicateGroups(groups)
            load(using: container)
            statusMessage = language.localized(
                "duplicate.status.resolvedAll",
                language.formatInteger(groups.count)
            )
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ transaction: Transaction) {
        selectedTransaction = transaction
        selectedCategoryID = transaction.categoryID
        selectedKind = transaction.resolvedKind
        newCategoryIsIncome = selectedKind == .income
        statusMessage = nil
    }

    func setSelectedCategory(_ categoryID: UUID?) {
        selectedCategoryID = categoryID
    }

    func createCategory(using container: AppContainer) {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Choose a name before creating the category."
            return
        }

        do {
            let category = try container.categoryRepository.fetchOrCreateBaseCategory(
                named: trimmedName,
                isIncome: newCategoryIsIncome
            )
            categories = try container.categoryRepository.fetchAll()
            selectedCategoryID = category.id
            newCategoryName = ""
            statusMessage = "Category '\(category.name)' created and selected."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyCategoryEdit(using container: AppContainer, createRule: Bool) {
        guard let transaction = selectedTransaction,
              let categoryID = selectedCategoryID else {
            errorMessage = "Choose a category before saving the movement."
            return
        }

        do {
            try container.correctionLearningService.applyCorrection(
                for: transaction,
                categoryID: categoryID,
                applyToFuture: createRule
            )
            load(using: container)
            if let refreshed = transactions.first(where: { $0.id == transaction.id }) {
                selectedTransaction = refreshed
                selectedCategoryID = refreshed.categoryID
            }
            statusMessage = createRule
                ? "Category updated and rule created from this movement."
                : "Category updated for the selected movement."
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyKindEdit(using container: AppContainer) {
        guard let transaction = selectedTransaction else {
            errorMessage = "Choose a movement before updating its type."
            return
        }

        do {
            try container.transactionRepository.updateTransactionKind(transactionID: transaction.id, kind: selectedKind)
            load(using: container)
            if let refreshed = transactions.first(where: { $0.id == transaction.id }) {
                selectedTransaction = refreshed
                selectedKind = refreshed.resolvedKind
            }
            statusMessage = "Movement type updated to \(selectedKind.rawValue)."
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recategorizeSelectedType(using container: AppContainer) async {
        isRecategorizing = true
        recategorizationSummary = nil
        defer { isRecategorizing = false }

        let targetKind = batchRecategorizationKind

        do {
            let candidates = try container.transactionRepository.fetchAll()
                .filter { $0.resolvedKind == targetKind }
                .filter { $0.categorizationSourceRaw != CategorizationSource.manual.rawValue }

            guard !candidates.isEmpty else {
                recategorizationSummary = AppLanguage.currentSelection.localized("transactions.noRecategorizationCandidates")
                return
            }

            let result = try await container.recategorizationService.analyze(candidates)

            load(using: container)
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)

            if result.autoResolved == 0 && result.suggestionsCreated == 0 {
                recategorizationSummary = AppLanguage.currentSelection.localized("transactions.noRecategorizationImprovements")
            } else {
                recategorizationSummary = AppLanguage.currentSelection.localized(
                    "transactions.recategorizationSummary",
                    AppLanguage.currentSelection.formatInteger(result.autoResolved),
                    AppLanguage.currentSelection.formatInteger(result.suggestionsCreated)
                )
            }
            statusMessage = AppLanguage.currentSelection.localized("transactions.recategorizationReviewHint")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func normalizedDTO(from transaction: Transaction) -> NormalizedTransactionDTO {
        NormalizedTransactionDTO(
            externalID: transaction.externalID,
            bookingDate: transaction.bookingDate,
            valueDate: transaction.valueDate,
            rawDescription: transaction.rawDescription,
            cleanedDescription: transaction.cleanedDescription,
            merchantDisplayName: transaction.merchantDisplayName,
            merchantCanonicalName: transaction.merchantCanonicalName,
            amount: transaction.amount,
            currencyCode: transaction.currencyCode,
            accountName: transaction.accountName,
            sign: transaction.amount >= 0 ? 1 : -1,
            fingerprint: transaction.fingerprint
        )
    }

    private func pendingDuplicateGroups(from transactions: [Transaction]) -> [DuplicateMovementGroup] {
        let grouped = Dictionary(grouping: transactions.filter {
            $0.duplicateReviewStatusRaw == DuplicateReviewStatus.pending.rawValue
        }) { $0.duplicateGroupID }

        return grouped.compactMap { groupID, members in
            guard let groupID,
                  members.count >= 2,
                  let first = members.first else {
                return nil
            }

            let transactionIDs = members.map(\.id).sorted { $0.uuidString < $1.uuidString }
            return DuplicateMovementGroup(
                id: groupID,
                transactionIDs: transactionIDs,
                confidence: members.compactMap(\.duplicateConfidence).min() ?? 0,
                reasonKey: members.compactMap(\.duplicateReasonKey).first ?? "duplicate.reason.crossSource",
                recommendedKeepID: members.first(where: { member in
                    member.id == member.duplicateRecommendedKeepID
                })?.id
                    ?? first.duplicateRecommendedKeepID
                    ?? first.id
            )
        }
        .sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence {
                return lhs.id < rhs.id
            }
            return lhs.confidence > rhs.confidence
        }
    }


}
