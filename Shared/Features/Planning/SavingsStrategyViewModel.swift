import Foundation
import Observation

@MainActor
@Observable
final class SavingsStrategyViewModel {
    var config: SavingsStrategyConfig = .default
    var snapshot: SavingsStrategySnapshot?
    var availableMonths: [Date] = []
    var selectedMonthStart: Date?
    var categories: [Category] = []
    var isLoading = false
    var errorMessage: String?

    func load(using container: AppContainer, now: Date = .now) {
        isLoading = true
        defer { isLoading = false }

        do {
            config = container.savingsStrategyStore.load()
            let transactions = try container.transactionRepository.fetchAll()
            let allCategories = try container.categoryRepository.fetchAll()
            categories = allCategories
                .filter { !$0.isIncome }
                .sorted { lhs, rhs in
                    if lhs.sortOrder == rhs.sortOrder {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    return lhs.sortOrder < rhs.sortOrder
                }

            availableMonths = container.savingsStrategyService.availableMonthStarts(
                transactions: transactions,
                categories: allCategories,
                now: now
            )

            if let selectedMonthStart, availableMonths.contains(selectedMonthStart) {
                // Keep the user's month.
            } else {
                selectedMonthStart = availableMonths.first
            }

            snapshot = container.savingsStrategyService.buildSnapshot(
                transactions: transactions,
                categories: allCategories,
                config: config,
                monthStart: selectedMonthStart,
                now: now
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectMonth(_ monthStart: Date, using container: AppContainer) {
        selectedMonthStart = monthStart
        load(using: container)
    }

    func shiftMonth(by value: Int, using container: AppContainer) {
        guard let selectedMonthStart,
              let index = availableMonths.firstIndex(of: selectedMonthStart) else {
            return
        }
        let nextIndex = index - value
        guard availableMonths.indices.contains(nextIndex) else { return }
        selectMonth(availableMonths[nextIndex], using: container)
    }

    func applyPreset(_ preset: SavingsStrategyPreset, using container: AppContainer) {
        guard preset != .custom else { return }
        persist(config.applying(preset: preset), using: container)
    }

    func adjust(bucket: SavingsAllocationBucket, delta: Int, using container: AppContainer) {
        persist(config.adjusting(bucket: bucket, delta: delta), using: container)
    }

    func assign(categoryID: UUID, to bucket: SavingsAllocationBucket?, using container: AppContainer) {
        persist(config.assigning(categoryID, to: bucket), using: container)
    }

    func resetAssignments(using container: AppContainer) {
        var next = config
        next.categoryBucketOverrides = [:]
        persist(next, using: container)
    }

    func resetStrategy(using container: AppContainer) {
        container.savingsStrategyStore.reset()
        load(using: container)
    }

    func assignableCategories(in bucket: SavingsAllocationBucket) -> [Category] {
        categories.filter { config.bucket(for: $0) == bucket }
    }

    func unassignedCategories() -> [Category] {
        categories.filter { config.bucket(for: $0) == nil }
    }

    private func persist(_ config: SavingsStrategyConfig, using container: AppContainer) {
        self.config = config
        container.savingsStrategyStore.save(config)
        load(using: container)
    }
}
