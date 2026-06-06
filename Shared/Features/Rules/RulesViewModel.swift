import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class RulesViewModel {
    var rules: [Rule] = []
    var searchText: String = ""
    var isShowingAddSheet = false
    var editingRule: Rule?
    var errorMessage: String?
    
    var filteredRules: [Rule] {
        if searchText.isEmpty {
            return rules
        }
        return rules.filter { rule in
            rule.name.localizedCaseInsensitiveContains(searchText) ||
            (rule.merchantContains?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (rule.descriptionContains?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    func load(using container: AppContainer) {
        do {
            rules = try container.ruleRepository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func toggleRule(_ rule: Rule, using container: AppContainer) {
        do {
            try container.ruleRepository.toggleRule(id: rule.id)
            load(using: container)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteRule(_ rule: Rule, using container: AppContainer) {
        do {
            try container.ruleRepository.delete(rule)
            load(using: container)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
