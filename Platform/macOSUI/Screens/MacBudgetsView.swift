import SwiftUI
import SwiftData

@MainActor
@Observable
final class BudgetsViewModel {
    var budgets: [Budget] = []
    var categories: [Category] = []
    var transactions: [Transaction] = []
    var errorMessage: String?
    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    func load(using container: AppContainer) {
        do {
            budgets = try container.budgetRepository.fetch(forMonthYear: currentMonthYear)
            categories = try container.categoryRepository.fetchAll()
            
            // Limit transactions to the current month for calculation
            let allTransactions = try container.transactionRepository.fetchAll()
            let calendar = Calendar.current
            let now = Date()
            
            transactions = allTransactions.filter { 
                let isSameMonth = calendar.isDate($0.accountingDate, equalTo: now, toGranularity: .month)
                let isSameYear = calendar.isDate($0.accountingDate, equalTo: now, toGranularity: .year)
                return isSameMonth && isSameYear
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func addBudget(categoryID: UUID, amount: Decimal, using container: AppContainer) -> Bool {
        guard amount > .zero else {
            errorMessage = AppLanguage.currentSelection.localized("budget.error.invalidLimit")
            return false
        }

        let budget = Budget(categoryID: categoryID, monthYear: currentMonthYear, limitAmount: amount)
        do {
            try container.budgetRepository.save(budget)
            load(using: container)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteBudget(_ budget: Budget, using container: AppContainer) {
        do {
            try container.budgetRepository.delete(budget)
            load(using: container)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func spent(for categoryID: UUID) -> Decimal {
        transactions
            .filter { $0.categoryID == categoryID && $0.resolvedKind == .expense }
            .reduce(0) { $0 + abs($1.amount) }
    }
}

struct MacBudgetsView: View {
    @Environment(\.appContainer) private var appContainer
    @State private var viewModel = BudgetsViewModel()
    @State private var showNewBudgetSheet = false
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(LocalizedStringKey("Monthly Budgets"))
                            .font(AppTypography.displayTitle)
                        Text(String(localized: "Track your spending limits for \(viewModel.currentMonthYear)"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    PrimaryButton(title: LocalizedStringKey("New Budget")) {
                        showNewBudgetSheet = true
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if viewModel.budgets.isEmpty {
                    EmptyStateView(
                        title: LocalizedStringKey("No limits set"),
                        message: LocalizedStringKey("Create a budget to monitor spending for specific categories."),
                        systemImage: "target"
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: AppSpacing.large)], spacing: AppSpacing.large) {
                        ForEach(viewModel.budgets) { budget in
                            budgetCard(budget)
                        }
                    }
                }
            }
            .padding(AppSpacing.large)
        }
        .background(.windowBackground)
        .navigationTitle(LocalizedStringKey("Budgets"))
        .sheet(isPresented: $showNewBudgetSheet) {
            NewBudgetSheet(viewModel: viewModel, isPresented: $showNewBudgetSheet)
        }
        .onAppear {
            viewModel.load(using: appContainer)
        }
    }
    
    private func budgetCard(_ budget: Budget) -> some View {
        let spent = viewModel.spent(for: budget.categoryID)
        let progress = budget.limitAmount > .zero
            ? min(1.0, Double(truncating: NSDecimalNumber(decimal: spent / budget.limitAmount)))
            : 0
        let isOverLimit = budget.limitAmount > .zero && spent >= budget.limitAmount
        let isNearLimit = progress >= budget.alertThreshold
        
        // Find category name
        let categoryName = viewModel.categories.first(where: { $0.id == budget.categoryID })?.name ?? String(localized: "Unknown Category")
        
        return VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Text(categoryName)
                    .font(AppTypography.sectionTitle)
                Spacer()
                Button {
                    viewModel.deleteBudget(budget, using: appContainer)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            HStack(alignment: .lastTextBaseline) {
                Text(spent.privacyFormatted(hidden: isPrivacyModeEnabled, language: appLanguage))
                    .font(AppTypography.heroNumber.monospacedDigit())
                    .foregroundStyle(isOverLimit ? AppColors.expense : .primary)
                Text(appLanguage.localized("of %@", budget.limitAmount.privacyFormatted(hidden: isPrivacyModeEnabled, language: appLanguage)))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppMaterials.thin)
                    Capsule()
                        .fill(isOverLimit ? AppColors.expense : (isNearLimit ? AppColors.warning : AppColors.income))
                        .frame(width: max(0, proxy.size.width * CGFloat(progress)))
                }
            }
            .frame(height: 12)
            
            if isOverLimit {
                Text(LocalizedStringKey("Limit exceeded"))
                    .font(.caption)
                    .foregroundStyle(AppColors.expense)
            } else if isNearLimit {
                Text(LocalizedStringKey("Approaching limit"))
                    .font(.caption)
                    .foregroundStyle(AppColors.warning)
            }
        }
        .glassCard()
    }
}

private struct NewBudgetSheet: View {
    @Bindable var viewModel: BudgetsViewModel
    @Binding var isPresented: Bool
    @Environment(\.appContainer) private var appContainer
    
    @State private var selectedCategoryID: UUID?
    @State private var limitAmountText: String = ""

    private var parsedLimitAmount: Decimal? {
        ImportValueParser.parseAmount(limitAmountText)
    }

    private var canSave: Bool {
        selectedCategoryID != nil && (parsedLimitAmount ?? .zero) > .zero
    }

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Text(LocalizedStringKey("Create Budget"))
                .font(AppTypography.screenTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Form {
                Picker(LocalizedStringKey("Category"), selection: $selectedCategoryID) {
                    Text(LocalizedStringKey("Select a category")).tag(UUID?.none)
                    ForEach(viewModel.categories.filter { !$0.isIncome }, id: \.id) { cat in
                        Text(cat.name).tag(Optional(cat.id))
                    }
                }
                
                TextField(LocalizedStringKey("Limit Amount (€)"), text: $limitAmountText)
            }
            .formStyle(.grouped)
            
            HStack {
                Button(LocalizedStringKey("Cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                PrimaryButton(title: LocalizedStringKey("Save Budget")) {
                    if let id = selectedCategoryID, let amount = parsedLimitAmount,
                       viewModel.addBudget(categoryID: id, amount: amount, using: appContainer) {
                        isPresented = false
                    }
                }
                .disabled(!canSave)
            }
        }
        .padding(AppSpacing.large)
        .frame(width: 400)
    }
}
