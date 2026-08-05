import Foundation
import Observation

struct SimilarTransactionGroup: Identifiable {
    let id: String
    let title: String
    let count: Int
    let representativeTransactionID: UUID
}

enum ReviewListFilter: String, CaseIterable, Identifiable {
    case all
    case lowConfidence
    case uncategorized
    case suggestions
    case similar

    var id: String { rawValue }

    var title: String {
        let language = AppLanguage.currentSelection
        switch self {
        case .all: return language.localized("review.filter.all")
        case .lowConfidence: return language.localized("review.filter.lowConfidence")
        case .uncategorized: return language.localized("review.filter.uncategorized")
        case .suggestions: return language.localized("review.filter.suggestions")
        case .similar: return language.localized("review.filter.similar")
        }
    }
}

@MainActor
@Observable
final class ReviewQueueViewModel {
    var pendingCount = 0
    var transactions: [Transaction] = [] {
        didSet { recomputeCaches() }
    }
    var selectedTransaction: Transaction? {
        didSet { updateSimilarCache() }
    }
    var categories: [Category] = []
    var selectedCategoryID: UUID?
    var selectedKind: TransactionKind = .expense
    var newCategoryName = ""
    var newCategoryIsIncome = false
    var createRuleFromCorrection = false
    var isLoadingAISuggestion = false
    var isRecategorizing = false
    var recategorizationSummary: String?
    var errorMessage: String?
    var statusMessage: String?
    var suggestedGroups: [SimilarTransactionGroup] = [] {
        didSet { updateFilteredListCache() }
    }
    var listFilter: ReviewListFilter = .all {
        didSet { updateFilteredListCache() }
    }

    private(set) var filteredList: [Transaction] = []
    private(set) var similarTransactions: [Transaction] = []

    private func recomputeCaches() {
        updateFilteredListCache()
        updateSimilarCache()
    }

    private func updateFilteredListCache() {
        switch listFilter {
        case .all:
            filteredList = transactions
        case .lowConfidence:
            filteredList = transactions.filter { $0.confidence < AppConfig.softAutoCategorizationThreshold }
        case .uncategorized:
            filteredList = transactions.filter { $0.categoryID == nil }
        case .suggestions:
            filteredList = transactions.filter(\.hasRecategorizationSuggestion)
        case .similar:
            let ids = Set(suggestedGroups.map { $0.representativeTransactionID })
            filteredList = transactions.filter { t in
                ids.contains(t.id) || !similarTransactions(for: t).isEmpty
            }
        }
    }

    private func updateSimilarCache() {
        guard let selectedTransaction else {
            similarTransactions = []
            return
        }
        similarTransactions = transactions.filter { $0.id != selectedTransaction.id && isSimilar($0, to: selectedTransaction) }
    }

    func load(using container: AppContainer) {
        do {
            transactions = try container.transactionRepository.fetchPendingReview()
            categories = try container.categoryRepository.fetchAll()
            pendingCount = transactions.count
            if let selectedTransaction,
               let refreshed = transactions.first(where: { $0.id == selectedTransaction.id }) {
                self.selectedTransaction = refreshed
                selectedCategoryID = refreshed.suggestedCategoryID ?? refreshed.categoryID
            } else {
                selectedTransaction = transactions.first
                selectedCategoryID = transactions.first?.suggestedCategoryID ?? transactions.first?.categoryID
            }
            selectedKind = selectedTransaction?.resolvedKind ?? .expense
            newCategoryIsIncome = (selectedTransaction?.amount ?? 0) > 0
            suggestedGroups = buildSuggestedGroups(from: transactions)
            recategorizationSummary = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ transaction: Transaction) {
        selectedTransaction = transaction
        selectedCategoryID = transaction.suggestedCategoryID ?? transaction.categoryID
        selectedKind = transaction.resolvedKind
        newCategoryIsIncome = transaction.amount > 0
        statusMessage = nil
    }

    func createCategory(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = language.localized("review.error.writeCategoryName")
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
            statusMessage = language.localized("review.status.categoryAvailable", category.name)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateSelectedKind(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction else {
            errorMessage = language.localized("review.error.selectTransactionBeforeType")
            return
        }

        do {
            try container.transactionRepository.updateTransactionKind(transactionID: transaction.id, kind: selectedKind)
            let previousID = transaction.id
            load(using: container)
            advanceSelection(after: previousID)
            statusMessage = language.localized("review.status.updatedType", selectedKind.rawValue)
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAsTransfer(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction else {
            errorMessage = language.localized("review.error.selectTransactionBeforeTransfer")
            return
        }
        do {
            try container.transactionRepository.updateTransactionKind(transactionID: transaction.id, kind: .transfer)
            let previousID = transaction.id
            load(using: container)
            advanceSelection(after: previousID)
            statusMessage = language.localized("review.status.markedAsTransfer")
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skipSelected() {
        guard let transaction = selectedTransaction else { return }
        advanceSelection(after: transaction.id)
        statusMessage = nil
    }

    func approveSelected(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction,
              let categoryID = selectedCategoryID ?? transaction.categoryID else {
            errorMessage = language.localized("review.error.selectTransactionWithCategory")
            return
        }
        let previousID = transaction.id
        applyDecision(for: transaction, categoryID: categoryID, using: container)
        if errorMessage == nil {
            advanceSelection(after: previousID)
        }
    }

    func reassignSelected(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction,
              let categoryID = selectedCategoryID else {
            errorMessage = language.localized("review.error.chooseCategoryBeforeCorrection")
            return
        }
        let previousID = transaction.id
        applyDecision(for: transaction, categoryID: categoryID, using: container)
        if errorMessage == nil {
            advanceSelection(after: previousID)
        }
    }

    func acceptSuggestedCategory(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction,
              let suggestedCategoryID = transaction.suggestedCategoryID else {
            errorMessage = language.localized("review.error.noCategorySuggestion")
            return
        }

        do {
            try container.correctionLearningService.applyCorrection(
                for: transaction,
                categoryID: suggestedCategoryID,
                subcategoryID: transaction.suggestedSubcategoryID,
                applyToFuture: createRuleFromCorrection
            )
            statusMessage = language.localized("review.status.suggestionAccepted")
            errorMessage = nil
            load(using: container)
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissSuggestedCategory(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction,
              transaction.hasRecategorizationSuggestion else {
            errorMessage = language.localized("review.error.noCategorySuggestion")
            return
        }

        do {
            try container.transactionRepository.clearRecategorizationSuggestion(transactionID: transaction.id)
            statusMessage = language.localized("review.status.suggestionDismissed")
            errorMessage = nil
            load(using: container)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptAllHighConfidenceSuggestions(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        do {
            let candidates = try container.transactionRepository.fetchPendingReview()
                .filter {
                    $0.hasRecategorizationSuggestion &&
                    ($0.suggestedConfidence ?? 0) >= AppConfig.softAutoCategorizationThreshold
                }

            for transaction in candidates {
                guard let categoryID = transaction.suggestedCategoryID else { continue }
                try container.correctionLearningService.applyCorrection(
                    for: transaction,
                    categoryID: categoryID,
                    subcategoryID: transaction.suggestedSubcategoryID,
                    applyToFuture: false
                )
            }

            load(using: container)
            statusMessage = language.localized(
                "review.status.acceptedHighConfidence",
                language.formatInteger(candidates.count)
            )
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyToSimilar(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction,
              let categoryID = selectedCategoryID else {
            errorMessage = language.localized("review.error.chooseCategoryBeforeSimilar")
            return
        }

        let similar = similarTransactions
        guard !similar.isEmpty else {
            errorMessage = language.localized("review.error.noSimilarMovements")
            return
        }

        do {
            try container.correctionLearningService.applyCorrection(
                for: transaction,
                categoryID: categoryID,
                applyToFuture: createRuleFromCorrection
            )

            for item in similar {
                try container.correctionLearningService.applyCorrection(
                    for: item,
                    categoryID: categoryID,
                    applyToFuture: false
                )
            }

            statusMessage = language.localized("review.status.appliedToSimilar", language.formatInteger(similar.count + 1))
            errorMessage = nil
            load(using: container)
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestAISuggestion(using container: AppContainer) async {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction else {
            errorMessage = language.localized("review.error.selectTransactionBeforeAI")
            return
        }

        isLoadingAISuggestion = true
        defer { isLoadingAISuggestion = false }

        let suggestion = await container.aiSuggestionService.suggestWithFoundationModel(
            for: transaction,
            categories: categories
        )

        guard let suggestion,
              let category = categories.first(where: { $0.name.caseInsensitiveCompare(suggestion.suggestedCategoryName) == .orderedSame }) else {
            errorMessage = nil
            statusMessage = language.localized("review.status.aiNoReliableCategory")
            return
        }

        selectedCategoryID = category.id
        statusMessage = language.localized("review.status.aiSuggests", category.name, language.formatPercent(suggestion.confidence))
        errorMessage = nil
    }

    // MARK: - ML Re-categorization

    func recategorizeAllPending(using container: AppContainer) async {
        let language = AppLanguage.currentSelection
        isRecategorizing = true
        recategorizationSummary = nil
        defer { isRecategorizing = false }

        do {
            let candidates = try container.transactionRepository.fetchRecategorizationCandidates()
            guard !candidates.isEmpty else {
                recategorizationSummary = language.localized("review.status.noCandidatesToRecategorize")
                return
            }

            let result = try await container.recategorizationService.analyze(candidates)

            load(using: container)
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)

            var parts: [String] = []
            if result.autoResolved > 0 {
                parts.append(language.localized("review.status.autoResolved", language.formatInteger(result.autoResolved)))
            }
            if result.suggestionsCreated > 0 {
                parts.append(language.localized("review.status.suggestionsUpdated", language.formatInteger(result.suggestionsCreated)))
            }
            if parts.isEmpty {
                recategorizationSummary = language.localized("review.status.mlNoImprovements")
            } else {
                recategorizationSummary = language.localized("review.status.mlRerun", parts.joined(separator: ", "))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private helpers

    private func applyDecision(for transaction: Transaction, categoryID: UUID, using container: AppContainer) {
        let language = AppLanguage.currentSelection
        do {
            try container.correctionLearningService.applyCorrection(
                for: transaction,
                categoryID: categoryID,
                applyToFuture: createRuleFromCorrection
            )
            statusMessage = language.localized("review.status.savedDecision", transaction.rawDescription)
            errorMessage = nil
            load(using: container)
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func advanceSelection(after transactionID: UUID) {
        guard let currentIndex = filteredList.firstIndex(where: { $0.id == transactionID }) else {
            selectedTransaction = filteredList.first
            return
        }
        let nextIndex = currentIndex + 1
        if nextIndex < filteredList.count {
            let next = filteredList[nextIndex]
            selectedTransaction = next
            selectedCategoryID = next.suggestedCategoryID ?? next.categoryID
            selectedKind = next.resolvedKind
        } else if currentIndex > 0 {
            let prev = filteredList[currentIndex - 1]
            selectedTransaction = prev
            selectedCategoryID = prev.suggestedCategoryID ?? prev.categoryID
            selectedKind = prev.resolvedKind
        } else {
            selectedTransaction = nil
            selectedCategoryID = nil
        }
    }

    private func similarTransactions(for transaction: Transaction) -> [Transaction] {
        transactions.filter { $0.id != transaction.id && isSimilar($0, to: transaction) }
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

    private func isSimilar(_ lhs: Transaction, to rhs: Transaction) -> Bool {
        let lhsIsIncome = lhs.amount >= 0
        let rhsIsIncome = rhs.amount >= 0
        if lhsIsIncome != rhsIsIncome {
            return false
        }

        if let leftMerchant = lhs.merchantCanonicalName?.lowercased(),
           let rightMerchant = rhs.merchantCanonicalName?.lowercased(),
           !leftMerchant.isEmpty,
           leftMerchant == rightMerchant {
            return true
        }

        let leftTokens = Set(signatureTokens(from: lhs.cleanedDescription.isEmpty ? lhs.rawDescription : lhs.cleanedDescription))
        let rightTokens = Set(signatureTokens(from: rhs.cleanedDescription.isEmpty ? rhs.rawDescription : rhs.cleanedDescription))
        let overlap = leftTokens.intersection(rightTokens).count

        return overlap >= 2
    }

    private func signatureTokens(from text: String) -> [String] {
        let normalized = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let stopWords: Set<String> = [
            "sepa", "bizum", "transferencia", "ord", "s", "compra", "recibo", "para", "con",
            "the", "and", "por", "ingreso", "enviado", "recibido"
        ]

        return normalized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !stopWords.contains($0) }
    }

    private func buildSuggestedGroups(from items: [Transaction]) -> [SimilarTransactionGroup] {
        var grouped: [String: [Transaction]] = [:]

        for transaction in items {
            let key = similarityKey(for: transaction)
            grouped[key, default: []].append(transaction)
        }

        return grouped.values
            .filter { $0.count >= 2 }
            .map { group in
                let representative = group[0]
                let title = representative.merchantCanonicalName?.isEmpty == false
                    ? representative.merchantCanonicalName!
                    : representative.cleanedDescription
                return SimilarTransactionGroup(
                    id: similarityKey(for: representative),
                    title: title,
                    count: group.count,
                    representativeTransactionID: representative.id
                )
            }
            .sorted { $0.count > $1.count }
    }

    private func similarityKey(for transaction: Transaction) -> String {
        if let merchant = transaction.merchantCanonicalName?.lowercased(), !merchant.isEmpty {
            return "merchant:\(merchant):\(transaction.amount >= 0 ? "income" : "expense")"
        }

        let tokens = signatureTokens(from: transaction.cleanedDescription.isEmpty ? transaction.rawDescription : transaction.cleanedDescription)
            .prefix(3)
            .joined(separator: "|")
        return "tokens:\(tokens):\(transaction.amount >= 0 ? "income" : "expense")"
    }
}
