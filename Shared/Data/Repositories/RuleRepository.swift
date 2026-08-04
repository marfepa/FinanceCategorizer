import Foundation
import SwiftData

@MainActor
final class RuleRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func fetchActiveRules() throws -> [Rule] {
        let context = makeContext()
        let descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate { $0.isEnabled == true },
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchAll() throws -> [Rule] {
        let context = makeContext()
        let descriptor = FetchDescriptor<Rule>(
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func delete(_ rule: Rule) throws {
        let context = makeContext()
        let ruleID = rule.id
        let descriptor = FetchDescriptor<Rule>(predicate: #Predicate { $0.id == ruleID })
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    func toggleRule(id: UUID) throws {
        let context = makeContext()
        let ruleID = id
        let descriptor = FetchDescriptor<Rule>(predicate: #Predicate { $0.id == ruleID })
        if let rule = try context.fetch(descriptor).first {
            rule.isEnabled.toggle()
            try context.save()
        }
    }

    func update(_ rule: Rule) throws {
        let context = makeContext()
        let ruleID = rule.id
        let descriptor = FetchDescriptor<Rule>(predicate: #Predicate { $0.id == ruleID })
        guard let existing = try context.fetch(descriptor).first else {
            return
        }

        existing.name = rule.name
        existing.isEnabled = rule.isEnabled
        existing.merchantContains = rule.merchantContains
        existing.descriptionContains = rule.descriptionContains
        existing.amountMin = rule.amountMin
        existing.amountMax = rule.amountMax
        existing.amountSign = rule.amountSign
        existing.targetCategoryID = rule.targetCategoryID
        existing.targetSubcategoryID = rule.targetSubcategoryID
        existing.priority = rule.priority
        existing.createdFromUserCorrection = rule.createdFromUserCorrection
        existing.hitCount = rule.hitCount
        try context.save()
    }

    func createRule(
        name: String,
        merchantContains: String? = nil,
        descriptionContains: String? = nil,
        amountMin: Decimal? = nil,
        amountMax: Decimal? = nil,
        amountSign: Int? = nil,
        targetCategoryID: UUID,
        createdFromUserCorrection: Bool
    ) throws {
        let context = makeContext()
        let rules = try context.fetch(FetchDescriptor<Rule>())
        let normalizedMerchant = merchantContains?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedDescription = descriptionContains?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if rules.contains(where: {
            ($0.merchantContains?.lowercased() == normalizedMerchant) &&
            ($0.descriptionContains?.lowercased() == normalizedDescription) &&
            $0.targetCategoryID == targetCategoryID
        }) {
            return
        }

        let rule = Rule(
            name: name,
            isEnabled: true,
            merchantContains: normalizedMerchant,
            descriptionContains: normalizedDescription,
            amountMin: amountMin,
            amountMax: amountMax,
            amountSign: amountSign,
            targetCategoryID: targetCategoryID,
            targetSubcategoryID: nil,
            priority: createdFromUserCorrection ? 200 : 100,
            createdFromUserCorrection: createdFromUserCorrection,
            hitCount: 0
        )
        context.insert(rule)
        try context.save()
    }

    func incrementHitCount(for ruleID: UUID) throws {
        let context = makeContext()
        let descriptor = FetchDescriptor<Rule>(predicate: #Predicate { $0.id == ruleID })
        guard let rule = try context.fetch(descriptor).first else { return }
        rule.hitCount += 1
        try context.save()
    }
}
