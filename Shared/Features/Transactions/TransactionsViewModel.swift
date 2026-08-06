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
        didSet { recomputeFilteredResults(debounce: true) }
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

    private var filterTask: Task<Void, Never>?

    func recomputeFilteredResults(debounce: Bool = false) {
        filterTask?.cancel()
        
        let snapshots = self.transactions.map(TransactionSnapshot.init)
        let query = self.searchText
        let startDate = self.filterStartDate
        let endDate = self.filterEndDate
        let catID = self.filterCategoryID
        let kind = self.filterKind
        let sortOrder = self.transactionDateSortOrder
        
        filterTask = Task {
            if debounce {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            if Task.isCancelled { return }

            let (resultIDs, income, expense, count) = await Task.detached(priority: .userInitiated) {
                var result = snapshots

                if let startDate {
                    result = result.filter { $0.bookingDate >= startDate }
                }
                if let endDate {
                    result = result.filter { $0.bookingDate <= endDate }
                }
                if let catID {
                    result = result.filter { $0.categoryID == catID }
                }
                if let kind {
                    result = result.filter { $0.resolvedKind == kind }
                }

                if !query.isEmpty {
                    result = result.filter {
                        $0.rawDescription.localizedCaseInsensitiveContains(query) ||
                        $0.cleanedDescription.localizedCaseInsensitiveContains(query)
                    }
                }

                switch sortOrder {
                case .newestFirst:
                    result.sort { $0.bookingDate > $1.bookingDate }
                case .oldestFirst:
                    result.sort { $0.bookingDate < $1.bookingDate }
                }

                var inc: Decimal = 0
                var exp: Decimal = 0
                for tx in result {
                    if tx.resolvedKind == .income {
                        inc += tx.amount
                    } else if tx.resolvedKind == .expense {
                        exp += tx.amount
                    }
                }
                
                return (result.map { $0.id }, inc, exp, result.count)
            }.value

            if Task.isCancelled { return }

            let txDict = Dictionary(uniqueKeysWithValues: self.transactions.map { ($0.id, $0) })
            self.sortedTransactions = resultIDs.compactMap { txDict[$0] }
            self.filteredIncome = income
            self.filteredExpense = expense
            self.filteredCount = count
        }
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
            let updatedCount = try container.correctionLearningService.applyCorrection(
                for: transaction,
                categoryID: categoryID,
                applyToFuture: createRule
            )
            load(using: container)
            if let refreshed = transactions.first(where: { $0.id == transaction.id }) {
                selectedTransaction = refreshed
                selectedCategoryID = refreshed.categoryID
            }
            if updatedCount > 1 {
                statusMessage = "Category updated for \(updatedCount) matching movements and saved for future imports."
            } else {
                statusMessage = "Category updated and rule saved for future imports."
            }
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
            try Task.checkCancellation()
            let candidates = try container.transactionRepository.fetchAll()
                .filter { $0.resolvedKind == targetKind }
                .filter { $0.categorizationSourceRaw != CategorizationSource.manual.rawValue }

            guard !candidates.isEmpty else {
                recategorizationSummary = AppLanguage.currentSelection.localized("transactions.noRecategorizationCandidates")
                return
            }

            try Task.checkCancellation()
            let result = try await container.recategorizationService.analyze(candidates)

            try Task.checkCancellation()
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
        } catch is CancellationError {
            // Ignore gracefully
            return
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
