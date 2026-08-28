import SwiftUI
import SwiftData

struct MacRulesView: View {
    @Environment(\.appContainer) private var appContainer
    @State private var viewModel = RulesViewModel()
    @Query private var categories: [Category]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Toolbar
            HStack {
                Text(LocalizedStringKey("Automation Rules"))
                    .font(AppTypography.displayTitle)
                
                Spacer()
                
                TextField(LocalizedStringKey("Search rules..."), text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                Button(action: { viewModel.isShowingAddSheet = true }) {
                    Label(LocalizedStringKey("Add Rule"), systemImage: "plus")
                }
                .appPrimaryGlassButton()
            }
            .padding(AppSpacing.large)
            
            // Rules Table
            Table(viewModel.filteredRules) {
                TableColumn(LocalizedStringKey("Status")) { rule in
                    Toggle("", isOn: Binding(
                        get: { rule.isEnabled },
                        set: { _ in viewModel.toggleRule(rule, using: appContainer) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .width(50)
                
                TableColumn(LocalizedStringKey("Rule Name")) { rule in
                    VStack(alignment: .leading) {
                        Text(rule.name)
                            .font(.headline)
                        if rule.createdFromUserCorrection {
                            Text(LocalizedStringKey("Learning System"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                
                TableColumn(LocalizedStringKey("Condition")) { rule in
                    VStack(alignment: .leading, spacing: 2) {
                        if let merchant = rule.merchantContains {
                            Label(String(localized: "Merchant: \(merchant)"), systemImage: "building.2")
                                .font(.caption)
                        }
                        if let desc = rule.descriptionContains {
                            Label(String(localized: "Description: \(desc)"), systemImage: "text.alignleft")
                                .font(.caption)
                        }
                        if rule.amountMin != nil || rule.amountMax != nil {
                            Label(LocalizedStringKey("Amount Range"), systemImage: "eurosign.circle")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                
                TableColumn(LocalizedStringKey("Category")) { rule in
                    if let category = categories.first(where: { $0.id == rule.targetCategoryID }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .foregroundStyle(category.isIncome ? AppColors.income : AppColors.accent)
                                .frame(width: 16, height: 16)
                            Text(category.name)
                        }
                    } else {
                        Text(LocalizedStringKey("Unknown"))
                            .foregroundStyle(.secondary)
                    }
                }
                
                TableColumn(LocalizedStringKey("Hits")) { rule in
                    Text("\(rule.hitCount)")
                        .foregroundStyle(.secondary)
                }
                .width(50)
                
                TableColumn(LocalizedStringKey("Actions")) { rule in
                    HStack {
                        Button(action: { viewModel.editingRule = rule }) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.deleteRule(rule, using: appContainer) }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
                .width(80)
            }
            .tableStyle(.inset)
        }
        .background(AppMaterials.card)
        .onAppear {
            viewModel.load(using: appContainer)
        }
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            RuleEditorSheet(categories: categories, onSave: {
                viewModel.load(using: appContainer)
                viewModel.isShowingAddSheet = false
            })
        }
        .sheet(item: $viewModel.editingRule) { rule in
            RuleEditorSheet(rule: rule, categories: categories, onSave: {
                viewModel.load(using: appContainer)
                viewModel.editingRule = nil
            })
        }
    }
}

extension Rule: Identifiable {}
