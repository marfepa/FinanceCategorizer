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

struct SimilarApplyPreview: Identifiable {
    let id = UUID()
    let categoryID: UUID
    let categoryName: String
    /// Selected movement plus similar pending ones.
    let explicitIDs: [UUID]
    /// Historical movements that will also change because they match by name.
    let propagatedCount: Int

    var totalCount: Int { explicitIDs.count + propagatedCount }
}

@MainActor
@Observable
final class ReviewQueueViewModel {
    private let directionPolicy = CategoryDirectionPolicy()
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
    /// Most recent undoable batch, shown in the undo banner.
    var lastBatch: CorrectionBatch?
    var similarApplyPreview: SimilarApplyPreview?
    @ObservationIgnored weak var undoManager: UndoManager?
    var suggestedGroups: [SimilarTransactionGroup] = [] {
        didSet { updateFilteredListCache() }
    }
    var listFilter: ReviewListFilter = .all {
        didSet { updateFilteredListCache() }
    }

    private(set) var filteredList: [Transaction] = []
    private(set) var similarTransactions: [Transaction] = []

    var compatibleCategories: [Category] {
        categories.filter {
            directionPolicy.isCompatible(categoryIsIncome: $0.isIncome, transactionKind: selectedKind)
        }
    }

    private var filterTask: Task<Void, Never>?
    private var similarTask: Task<Void, Never>?

    private func recomputeCaches() {
        updateFilteredListCache()
        updateSimilarCache()
    }

    private func updateFilteredListCache() {
        filterTask?.cancel()
        let snapshots = self.transactions.map(TransactionSnapshot.init)
        let filter = self.listFilter
        let suggestedGroups = self.suggestedGroups.map { $0.representativeTransactionID }
        let similarIds = Set(self.similarTransactions.map { $0.id })
        
        filterTask = Task {
            let resultIDs = await Task.detached(priority: .userInitiated) {
                switch filter {
                case .all:
                    return snapshots.map { $0.id }
                case .lowConfidence:
                    return snapshots.filter { $0.confidence < AppConfig.softAutoCategorizationThreshold }.map { $0.id }
                case .uncategorized:
                    return snapshots.filter { $0.categoryID == nil }.map { $0.id }
                case .suggestions:
                    return snapshots.filter { $0.suggestedCategoryID != nil }.map { $0.id }
                case .similar:
                    let ids = Set(suggestedGroups)
                    return snapshots.filter { t in
                        ids.contains(t.id) || similarIds.contains(t.id)
                    }.map { $0.id }
                }
            }.value
            
            if Task.isCancelled { return }
            let txDict = Dictionary(uniqueKeysWithValues: self.transactions.map { ($0.id, $0) })
            self.filteredList = resultIDs.compactMap { txDict[$0] }
        }
    }

    private func updateSimilarCache() {
        guard let selectedTransaction else {
            similarTransactions = []
            return
        }
        similarTransactions = similarTransactions(for: selectedTransaction)
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
        perform(advancingFrom: transaction.id, using: container) {
            try container.correctionBatchService.markAsTransfer(transactionID: transaction.id)
        }
        if errorMessage == nil {
            statusMessage = language.localized("review.status.markedAsTransfer")
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
        applyDecision(for: transaction, categoryID: categoryID, action: .approve, using: container)
    }

    func reassignSelected(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction,
              let categoryID = selectedCategoryID else {
            errorMessage = language.localized("review.error.chooseCategoryBeforeCorrection")
            return
        }
        applyDecision(for: transaction, categoryID: categoryID, action: .reassign, using: container)
    }

    func acceptSuggestedCategory(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction,
              let suggestedCategoryID = transaction.suggestedCategoryID else {
            errorMessage = language.localized("review.error.noCategorySuggestion")
            return
        }

        let request = CorrectionRequest(
            transactionID: transaction.id,
            categoryID: suggestedCategoryID,
            subcategoryID: transaction.suggestedSubcategoryID
        )
        let createRules = createRuleFromCorrection
        perform(advancingFrom: transaction.id, using: container) {
            try container.correctionBatchService.applyCategories(
                [request],
                action: .acceptSuggestion,
                propagateToMatches: false,
                rulePolicy: .explicit,
                createRules: createRules
            )
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

            let requests = candidates.compactMap { transaction -> CorrectionRequest? in
                guard let categoryID = transaction.suggestedCategoryID else { return nil }
                return CorrectionRequest(
                    transactionID: transaction.id,
                    categoryID: categoryID,
                    subcategoryID: transaction.suggestedSubcategoryID
                )
            }
            guard !requests.isEmpty else {
                statusMessage = language.localized("review.status.acceptedHighConfidence", language.formatInteger(0))
                errorMessage = nil
                return
            }
            let batch = try container.correctionBatchService.applyCategories(
                requests,
                action: .acceptHighConfidence,
                propagateToMatches: false,
                rulePolicy: .none,
                createRules: false
            )
            didCommit(batch, using: container)
            statusMessage = language.localized(
                "review.status.acceptedHighConfidence",
                language.formatInteger(batch.explicitCount)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Computes how many movements "apply to similar" would change, so the
    /// view can ask for confirmation before anything is written.
    func prepareApplyToSimilar(using container: AppContainer) {
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
            let explicitIDs = try container.correctionBatchService.compatibleTransactionIDs(
                [transaction.id] + similar.map(\.id),
                categoryID: categoryID
            )
            guard explicitIDs.first == transaction.id else {
                errorMessage = language.localized("review.error.incompatibleCategory")
                return
            }
            let propagatedCount = try container.correctionBatchService.propagationCount(for: explicitIDs)
            similarApplyPreview = SimilarApplyPreview(
                categoryID: categoryID,
                categoryName: categories.first(where: { $0.id == categoryID })?.name ?? "",
                explicitIDs: explicitIDs,
                propagatedCount: propagatedCount
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmApplyToSimilar(using container: AppContainer) {
        guard let preview = similarApplyPreview else { return }
        similarApplyPreview = nil
        // An import or edit may have changed the scope since the dialog opened:
        // never apply a different number than the one the user confirmed.
        if let current = try? container.correctionBatchService.propagationCount(for: preview.explicitIDs),
           current != preview.propagatedCount {
            similarApplyPreview = SimilarApplyPreview(
                categoryID: preview.categoryID,
                categoryName: preview.categoryName,
                explicitIDs: preview.explicitIDs,
                propagatedCount: current
            )
            return
        }
        let requests = preview.explicitIDs.map { CorrectionRequest(transactionID: $0, categoryID: preview.categoryID) }
        let createRules = createRuleFromCorrection
        perform(advancingFrom: preview.explicitIDs.first, using: container) {
            try container.correctionBatchService.applyCategories(
                requests,
                action: .applyToSimilar,
                propagateToMatches: true,
                rulePolicy: .explicit,
                createRules: createRules
            )
        }
    }

    // MARK: Undo

    func undo(_ batch: CorrectionBatch, using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard !container.correctionBatchService.isReverted(batch.id) else { return }
        do {
            try container.correctionBatchService.revert(batchID: batch.id)
            if lastBatch?.id == batch.id {
                lastBatch = nil
            }
            load(using: container)
            if let restoredID = batch.transactionIDs.first,
               let restored = transactions.first(where: { $0.id == restoredID }) {
                select(restored)
            }
            statusMessage = batch.totalCount == 0
                ? language.localized("review.undo.ruleRemoved")
                : Self.plural("review.undo.done", batch.totalCount, language: language)
            errorMessage = nil
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Undo triggered from the banner. When the batch is the top entry of the
    /// window's undo stack it goes through the UndoManager, so the next ⌘Z
    /// targets the previous action instead of a no-op.
    func undoFromBanner(_ batch: CorrectionBatch, using container: AppContainer) {
        let actionName = AppLanguage.currentSelection.localized("review.undo.actionName")
        if let undoManager, undoManager.canUndo, undoManager.undoActionName == actionName,
           lastBatch?.id == batch.id {
            undoManager.undo()
        } else {
            undo(batch, using: container)
        }
    }

    func undoLast(using container: AppContainer) {
        guard let lastBatch else { return }
        undo(lastBatch, using: container)
    }

    func createSuggestedRule(using container: AppContainer) {
        let language = AppLanguage.currentSelection
        guard let batch = lastBatch, batch.hasRuleSuggestion else { return }
        do {
            if let ruleBatch = try container.correctionBatchService.createSuggestedRule(from: batch) {
                lastBatch = ruleBatch
                registerUndo(for: ruleBatch, using: container)
                statusMessage = language.localized("review.undo.ruleCreated")
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissUndoBanner() {
        lastBatch = nil
    }

    /// Message for the undo banner, e.g. "Saved: 1 movement and 12 from the same merchant."
    func bannerMessage(for batch: CorrectionBatch) -> String {
        let language = AppLanguage.currentSelection
        if batch.totalCount == 0 {
            return language.localized("review.undo.ruleCreated")
        }
        if batch.propagatedCount > 0 {
            return language.localized(
                "review.undo.savedWithSimilar",
                Self.movementCount(batch.explicitCount, language: language),
                Self.movementCount(batch.propagatedCount, language: language)
            )
        }
        return Self.plural("review.undo.saved", batch.explicitCount, language: language)
    }

    /// "1 movement" / "3 movements", localized.
    static func movementCount(_ count: Int, language: AppLanguage) -> String {
        plural("review.count.movements", count, language: language)
    }

    static func plural(_ key: String, _ count: Int, language: AppLanguage) -> String {
        count == 1
            ? language.localized(key + ".one")
            : language.localized(key + ".other", language.formatInteger(count))
    }

    private func perform(
        advancingFrom transactionID: UUID?,
        using container: AppContainer,
        _ work: () throws -> CorrectionBatch
    ) {
        do {
            let batch = try work()
            didCommit(batch, using: container)
            if let transactionID {
                advanceSelection(after: transactionID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func didCommit(_ batch: CorrectionBatch, using container: AppContainer) {
        lastBatch = batch
        errorMessage = nil
        statusMessage = nil
        registerUndo(for: batch, using: container)
        load(using: container)
        NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
    }

    private func registerUndo(for batch: CorrectionBatch, using container: AppContainer) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { viewModel in
            MainActor.assumeIsolated {
                viewModel.undo(batch, using: container)
            }
        }
        undoManager.setActionName(AppLanguage.currentSelection.localized("review.undo.actionName"))
    }

    func requestAISuggestion(using container: AppContainer) async {
        let language = AppLanguage.currentSelection
        guard let transaction = selectedTransaction else {
            errorMessage = language.localized("review.error.selectTransactionBeforeAI")
            return
        }

        isLoadingAISuggestion = true
        defer { isLoadingAISuggestion = false }

        do {
            try Task.checkCancellation()
            let suggestion = await container.aiSuggestionService.suggestWithFoundationModel(
                for: transaction,
                categories: categories
            )

            try Task.checkCancellation()
            guard let suggestion,
                  let category = categories.first(where: { $0.name.caseInsensitiveCompare(suggestion.suggestedCategoryName) == .orderedSame }) else {
                errorMessage = nil
                statusMessage = language.localized("review.status.aiNoReliableCategory")
                return
            }

            selectedCategoryID = category.id
            statusMessage = language.localized("review.status.aiSuggests", category.name, language.formatPercent(suggestion.confidence))
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - ML Re-categorization

    func recategorizeAllPending(using container: AppContainer) async {
        let language = AppLanguage.currentSelection
        isRecategorizing = true
        recategorizationSummary = nil
        defer { isRecategorizing = false }

        do {
            try Task.checkCancellation()
            let candidates = try container.transactionRepository.fetchRecategorizationCandidates()
            guard !candidates.isEmpty else {
                recategorizationSummary = language.localized("review.status.noCandidatesToRecategorize")
                return
            }

            try Task.checkCancellation()
            let result = try await container.recategorizationService.analyze(candidates)

            try Task.checkCancellation()
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
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private helpers

    private func applyDecision(
        for transaction: Transaction,
        categoryID: UUID,
        action: CorrectionAction,
        using container: AppContainer
    ) {
        let request = CorrectionRequest(transactionID: transaction.id, categoryID: categoryID)
        let createRules = createRuleFromCorrection
        perform(advancingFrom: transaction.id, using: container) {
            try container.correctionBatchService.applyCategories(
                [request],
                action: action,
                propagateToMatches: false,
                rulePolicy: .explicit,
                createRules: createRules
            )
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
        let targetSnapshot = TransactionSnapshot(from: transaction)
        return transactions.filter { $0.id != transaction.id && Self.isSimilar(snapshot: TransactionSnapshot(from: $0), to: targetSnapshot) }
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

    private nonisolated static func isSimilar(snapshot lhs: TransactionSnapshot, to rhs: TransactionSnapshot) -> Bool {
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

    private nonisolated static func signatureTokens(from text: String) -> [String] {
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

        let tokens = ReviewQueueViewModel.signatureTokens(from: transaction.cleanedDescription.isEmpty ? transaction.rawDescription : transaction.cleanedDescription)
            .prefix(3)
            .joined(separator: "|")
        return "tokens:\(tokens):\(transaction.amount >= 0 ? "income" : "expense")"
    }
}
