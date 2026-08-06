import SwiftUI
import SwiftData

struct RuleEditorSheet: View {
    @Environment(\.appContainer) private var appContainer
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    
    let rule: Rule?
    let categories: [Category]
    let onSave: () -> Void
    
    @State private var name: String = ""
    @State private var merchantContains: String = ""
    @State private var descriptionContains: String = ""
    @State private var amountMin: String = ""
    @State private var amountMax: String = ""
    @State private var targetCategoryID: UUID = UUID()
    @State private var isEnabled: Bool = true
    @State private var saveError: String? = nil
    
    init(rule: Rule? = nil, categories: [Category], onSave: @escaping () -> Void) {
        self.rule = rule
        self.categories = categories
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("ruleEditor.information")) {
                    TextField(appLanguage.localized("Name"), text: $name)
                    Toggle(LocalizedStringKey("ruleEditor.enabled"), isOn: $isEnabled)
                }
                
                Section(LocalizedStringKey("ruleEditor.conditions")) {
                    TextField(appLanguage.localized("ruleEditor.merchantContains"), text: $merchantContains)
                    TextField(appLanguage.localized("ruleEditor.descriptionContains"), text: $descriptionContains)
                    
                    HStack {
                        TextField(appLanguage.localized("ruleEditor.minAmount"), text: $amountMin)
                        TextField(appLanguage.localized("ruleEditor.maxAmount"), text: $amountMax)
                    }
                }
                
                Section(LocalizedStringKey("Action")) {
                    Picker(LocalizedStringKey("ruleEditor.assignCategory"), selection: $targetCategoryID) {
                        ForEach(categories.sorted { $0.name < $1.name }) { category in
                            HStack {
                                Text(category.iconName)
                                Text(category.name)
                            }
                            .tag(category.id)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(rule == nil ? appLanguage.localized("ruleEditor.newRule") : appLanguage.localized("ruleEditor.editRule"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appLanguage.localized("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appLanguage.localized("Save")) { save() }
                        .disabled(name.isEmpty || (merchantContains.isEmpty && descriptionContains.isEmpty))
                }
            }
            .alert(appLanguage.localized("Error"), isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button(appLanguage.localized("OK"), role: .cancel) { }
            } message: {
                if let error = saveError {
                    Text(error)
                }
            }
            .onAppear {
                if let rule = rule {
                    name = rule.name
                    merchantContains = rule.merchantContains ?? ""
                    descriptionContains = rule.descriptionContains ?? ""
                    amountMin = rule.amountMin?.description ?? ""
                    amountMax = rule.amountMax?.description ?? ""
                    targetCategoryID = rule.targetCategoryID
                    isEnabled = rule.isEnabled
                } else if !categories.isEmpty {
                    targetCategoryID = categories[0].id
                }
            }
        }
        .frame(width: 450, height: 500)
    }
    
    private func save() {
        do {
            let mMin = ImportValueParser.parseAmount(amountMin)
            let mMax = ImportValueParser.parseAmount(amountMax)
            
            if let existing = rule {
                existing.name = name
                existing.merchantContains = merchantContains.isEmpty ? nil : merchantContains
                existing.descriptionContains = descriptionContains.isEmpty ? nil : descriptionContains
                existing.amountMin = mMin
                existing.amountMax = mMax
                existing.targetCategoryID = targetCategoryID
                existing.isEnabled = isEnabled
                try appContainer.ruleRepository.update(existing)
            } else {
                try appContainer.ruleRepository.createRule(
                    name: name,
                    merchantContains: merchantContains.isEmpty ? nil : merchantContains,
                    descriptionContains: descriptionContains.isEmpty ? nil : descriptionContains,
                    amountMin: mMin,
                    amountMax: mMax,
                    targetCategoryID: targetCategoryID,
                    createdFromUserCorrection: false
                )
            }
            onSave()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
