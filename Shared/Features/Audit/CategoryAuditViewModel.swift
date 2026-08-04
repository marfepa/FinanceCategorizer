import Foundation
import Observation

enum CategoryAuditFilter: String, CaseIterable, Identifiable {
    case all
    case suggestions
    case lowConfidence
    case uncategorized
    case manual

    var id: String { rawValue }

    var title: String {
        AppLanguage.currentSelection.localized("audit.filter.\(rawValue)")
    }
}

@MainActor
@Observable
final class CategoryAuditViewModel {
    var transactions: [Transaction] = []
    var categories: [Category] = []
    var selectedTransactionIDs: Set<UUID> = []
    var selectedTransaction: Transaction?
    var filter: CategoryAuditFilter = .all
    var searchText = ""
    var isAnalyzing = false
    var statusMessage: String?
    var errorMessage: String?

    var eligibleTransactions: [Transaction] {
        transactions.filter { $0.resolvedKind != .transfer }
    }

    var visibleTransactions: [Transaction] {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return eligibleTransactions.filter { transaction in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .suggestions:
                matchesFilter = transaction.hasRecategorizationSuggestion
            case .lowConfidence:
                matchesFilter = (transaction.suggestedConfidence ?? transaction.confidence) < AppConfig.softAutoCategorizationThreshold
            case .uncategorized:
                matchesFilter = transaction.categoryID == nil
            case .manual:
                matchesFilter = transaction.categorizationSourceRaw == CategorizationSource.manual.rawValue
            }

            guard matchesFilter, !normalizedSearch.isEmpty else { return matchesFilter }
            return searchableText(for: transaction).lowercased().contains(normalizedSearch)
        }
    }

    var analyzedCount: Int {
        eligibleTransactions.count { $0.categoryID != nil || $0.hasRecategorizationSuggestion }
    }

    var suggestionCount: Int {
        eligibleTransactions.count(where: \.hasRecategorizationSuggestion)
    }

    var lowConfidenceCount: Int {
        eligibleTransactions.count {
            ($0.suggestedConfidence ?? $0.confidence) < AppConfig.softAutoCategorizationThreshold
        }
    }

    var uncategorizedCount: Int {
        eligibleTransactions.count(where: { $0.categoryID == nil })
    }

    var confirmedCount: Int {
        max(eligibleTransactions.count - suggestionCount - uncategorizedCount, 0)
    }

    var selectedVisibleCount: Int {
        visibleTransactions.count { selectedTransactionIDs.contains($0.id) }
    }

    func load(using container: AppContainer) {
        do {
            transactions = try container.transactionRepository.fetchAll()
            categories = try container.categoryRepository.fetchAll()
            selectedTransaction = selectedTransaction.flatMap { selected in
                transactions.first(where: { $0.id == selected.id })
            }
            selectedTransactionIDs = selectedTransactionIDs.intersection(Set(transactions.map(\.id)))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func analyzeAll(using container: AppContainer) async {
        await analyze(transactions: eligibleTransactions, using: container)
    }

    func analyzeSelection(using container: AppContainer) async {
        let selected = transactions.filter { selectedTransactionIDs.contains($0.id) }
        await analyze(transactions: selected, using: container)
    }

    func analyze(transactions: [Transaction], using container: AppContainer) async {
        guard !isAnalyzing else { return }
        guard !transactions.isEmpty else {
            statusMessage = AppLanguage.currentSelection.localized("audit.status.noTransactions")
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let result = try await container.recategorizationService.analyze(transactions)
            load(using: container)
            statusMessage = AppLanguage.currentSelection.localized(
                "audit.status.analysisComplete",
                AppLanguage.currentSelection.formatInteger(result.evaluatedCount),
                AppLanguage.currentSelection.formatInteger(result.suggestionsCreated),
                AppLanguage.currentSelection.formatInteger(result.autoResolved)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptSelected(using container: AppContainer) {
        let selected = transactions.filter {
            selectedTransactionIDs.contains($0.id) && $0.suggestedCategoryID != nil
        }
        applySuggestions(selected, using: container, statusKey: "audit.status.accepted")
    }

    func accept(_ transaction: Transaction, using container: AppContainer) {
        guard transaction.suggestedCategoryID != nil else { return }
        applySuggestions([transaction], using: container, statusKey: "audit.status.accepted")
    }

    func assignCategory(_ categoryID: UUID, to transaction: Transaction, using container: AppContainer) {
        guard categories.contains(where: { $0.id == categoryID }) else {
            errorMessage = AppLanguage.currentSelection.localized("audit.status.categoryUnavailable")
            return
        }

        do {
            try container.correctionLearningService.applyCorrection(
                for: transaction,
                categoryID: categoryID,
                subcategoryID: nil,
                applyToFuture: false
            )
            load(using: container)
            statusMessage = AppLanguage.currentSelection.localized(
                "audit.status.assigned",
                categoryName(for: categoryID)
            )
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptAllHighConfidence(using container: AppContainer) {
        let candidates = eligibleTransactions.filter {
            $0.suggestedCategoryID != nil &&
            ($0.suggestedConfidence ?? 0) >= AppConfig.softAutoCategorizationThreshold
        }
        applySuggestions(candidates, using: container, statusKey: "audit.status.acceptedHighConfidence")
    }

    func dismissSelected(using container: AppContainer) {
        let selected = transactions.filter {
            selectedTransactionIDs.contains($0.id) && $0.hasRecategorizationSuggestion
        }
        guard !selected.isEmpty else {
            statusMessage = AppLanguage.currentSelection.localized("audit.status.noSelection")
            return
        }

        do {
            for transaction in selected {
                try container.transactionRepository.clearRecategorizationSuggestion(transactionID: transaction.id)
            }
            load(using: container)
            statusMessage = AppLanguage.currentSelection.localized(
                "audit.status.dismissed",
                AppLanguage.currentSelection.formatInteger(selected.count)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismiss(_ transaction: Transaction, using container: AppContainer) {
        guard transaction.hasRecategorizationSuggestion else { return }
        do {
            try container.transactionRepository.clearRecategorizationSuggestion(transactionID: transaction.id)
            load(using: container)
            statusMessage = AppLanguage.currentSelection.localized("audit.status.dismissed", "1")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectAllVisible() {
        selectedTransactionIDs.formUnion(visibleTransactions.map(\.id))
    }

    func clearSelection() {
        selectedTransactionIDs.removeAll()
    }

    func toggleSelection(for transaction: Transaction) {
        if selectedTransactionIDs.contains(transaction.id) {
            selectedTransactionIDs.remove(transaction.id)
        } else {
            selectedTransactionIDs.insert(transaction.id)
        }
    }

    func categoryName(for id: UUID?) -> String {
        guard let id, let category = categories.first(where: { $0.id == id }) else {
            return AppLanguage.currentSelection.localized("Uncategorized")
        }
        return category.name
    }

    func statusKey(for transaction: Transaction) -> String {
        if transaction.hasRecategorizationSuggestion { return "audit.status.needsReview" }
        if transaction.categorizationSourceRaw == CategorizationSource.manual.rawValue { return "audit.status.manual" }
        if transaction.categoryID == nil { return "audit.status.uncategorized" }
        return "audit.status.confirmed"
    }

    func confidence(for transaction: Transaction) -> Double {
        transaction.suggestedConfidence ?? transaction.confidence
    }

    func reason(for transaction: Transaction) -> String {
        transaction.suggestedReason ?? transaction.categorizationReason ?? AppLanguage.currentSelection.localized("audit.reason.none")
    }

    private func applySuggestions(_ transactions: [Transaction], using container: AppContainer, statusKey: String) {
        guard !transactions.isEmpty else {
            statusMessage = AppLanguage.currentSelection.localized("audit.status.noSelection")
            return
        }

        do {
            var appliedCount = 0
            for transaction in transactions {
                guard let categoryID = transaction.suggestedCategoryID else { continue }
                try container.correctionLearningService.applyCorrection(
                    for: transaction,
                    categoryID: categoryID,
                    subcategoryID: transaction.suggestedSubcategoryID,
                    applyToFuture: false
                )
                appliedCount += 1
            }
            load(using: container)
            statusMessage = AppLanguage.currentSelection.localized(
                statusKey,
                AppLanguage.currentSelection.formatInteger(appliedCount)
            )
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func searchableText(for transaction: Transaction) -> String {
        [
            transaction.rawDescription,
            transaction.cleanedDescription,
            transaction.merchantDisplayName ?? "",
            transaction.merchantCanonicalName ?? "",
            categoryName(for: transaction.categoryID),
            categoryName(for: transaction.suggestedCategoryID)
        ].joined(separator: " ")
    }
}
