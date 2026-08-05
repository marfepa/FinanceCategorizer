import SwiftUI

@MainActor
@Observable
final class SavingsGoalsViewModel {
    var snapshot: FinancialPlanningSnapshot?
    var accounts: [Account] = []
    var goals: [SavingsGoal] = []
    var isLoading = false
    var errorMessage: String?

    func load(using container: AppContainer) {
        isLoading = true
        defer { isLoading = false }

        do {
            let transactions = try container.transactionRepository.fetchAll()
            let categories = try container.categoryRepository.fetchAll()
            accounts = try container.accountRepository.fetchAll()
            goals = try container.savingsGoalRepository.fetchAll()
            snapshot = container.financialPlanningService.buildSnapshot(
                transactions: transactions,
                accounts: accounts,
                goals: goals,
                categories: categories
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveBalance(
        using container: AppContainer,
        accountID: UUID?,
        name: String,
        balanceText: String,
        isLiability: Bool
    ) {
        guard let balance = parseAmount(balanceText) else {
            errorMessage = String(localized: "Enter a valid amount.")
            return
        }

        do {
            try container.accountRepository.saveBalance(
                accountID: accountID,
                name: name,
                balance: balance,
                isLiability: isLiability
            )
            load(using: container)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveGoal(
        using container: AppContainer,
        id: UUID?,
        name: String,
        kind: SavingsGoalKind,
        targetText: String,
        allocatedText: String,
        monthlyText: String,
        targetDate: Date?
    ) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let targetAmount = parseAmount(targetText),
              targetAmount > .zero else {
            errorMessage = String(localized: "A goal name and a target greater than zero are required.")
            return
        }

        let goal = SavingsGoal(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            targetAmount: targetAmount,
            allocatedAmount: parseAmount(allocatedText) ?? .zero,
            monthlyContribution: parseAmount(monthlyText) ?? .zero,
            targetDate: targetDate
        )

        do {
            try container.savingsGoalRepository.save(goal)
            load(using: container)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGoal(using container: AppContainer, id: UUID) {
        do {
            try container.savingsGoalRepository.delete(id: id)
            load(using: container)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseAmount(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains(",") {
            return Decimal(string: trimmed.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "."))
        }
        return Decimal(string: trimmed)
    }
}

struct MacSavingsGoalsView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("isPrivacyModeEnabled") private var privacyStoredValue = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @State private var viewModel = SavingsGoalsViewModel()
    @State private var balanceEditor: BalanceEditorContext?
    @State private var isShowingGoalEditor = false

    var body: some View {
        GlassPageScaffold {
            header
        } content: {
            if let snapshot = viewModel.snapshot {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                    positionSection(snapshot)
                    goalsSection(snapshot)
                    projectionSection(snapshot)
                }
            } else if viewModel.isLoading {
                LoadingView(title: LocalizedStringKey("Loading financial position..."))
            } else {
                EmptyStateView(
                    title: LocalizedStringKey("No financial position yet"),
                    message: LocalizedStringKey("Import movements or confirm a current bank balance to start planning."),
                    systemImage: "banknote"
                )
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(AppColors.expense)
                    .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.card)
            }
        }
        .task {
            viewModel.load(using: appContainer)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            viewModel.load(using: appContainer)
        }
        .sheet(item: $balanceEditor) { context in
            BalanceEditorSheet(
                context: context,
                renderAmount: renderAmount,
                onSave: { context, balanceText, isLiability in
                    viewModel.saveBalance(
                        using: appContainer,
                        accountID: context.accountID,
                        name: context.name,
                        balanceText: balanceText,
                        isLiability: isLiability
                    )
                }
            )
        }
        .sheet(isPresented: $isShowingGoalEditor) {
            SavingsGoalEditorSheet { name, kind, target, allocated, monthly, date in
                viewModel.saveGoal(
                    using: appContainer,
                    id: nil,
                    name: name,
                    kind: kind,
                    targetText: target,
                    allocatedText: allocated,
                    monthlyText: monthly,
                    targetDate: date
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                Text(LocalizedStringKey("Savings Goals"))
                    .font(AppTypography.displayTitle)
                Text(LocalizedStringKey("Separate what you have from what you save and what you are planning."))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                privacyStoredValue.toggle()
            } label: {
                Label(
                    privacyStoredValue ? LocalizedStringKey("Amounts hidden") : LocalizedStringKey("Amounts visible"),
                    systemImage: privacyStoredValue ? "eye.slash.fill" : "eye.fill"
                )
                .font(.caption.weight(.semibold))
            }
            .appSecondaryGlassButton()
            .controlSize(.small)
        }
    }

    private func positionSection(_ snapshot: FinancialPlanningSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack(alignment: .firstTextBaseline) {
                Label(LocalizedStringKey("Accumulated balance"), systemImage: "banknote.fill")
                    .font(AppTypography.sectionTitle)
                Spacer()
                Text(snapshot.isBalanceConfirmed
                     ? LocalizedStringKey("Confirmed")
                     : LocalizedStringKey("Needs confirmation"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(snapshot.isBalanceConfirmed ? AppColors.income : AppColors.warning)
            }

            HStack(spacing: AppLayoutMetrics.contentGap) {
                PositionValue(title: "Total balance", value: renderAmount(snapshot.totalBalance), tint: AppColors.income)
                PositionValue(title: "Assigned to goals", value: renderAmount(snapshot.allocatedToGoals), tint: AppColors.neutral)
                PositionValue(title: "Available to assign", value: renderAmount(snapshot.availableBalance), tint: snapshot.availableBalance >= .zero ? AppColors.income : AppColors.expense)
            }

            ForEach(snapshot.positions) { position in
                HStack(spacing: AppLayoutMetrics.contentGap) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(position.name)
                            .font(.headline)
                        Text(position.source == .estimated
                             ? LocalizedStringKey("Estimated from imported movements")
                             : LocalizedStringKey("Confirmed balance"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(renderAmount(position.signedBalance))
                        .font(.headline.weight(.semibold))
                    Button(LocalizedStringKey("Confirm balance")) {
                        balanceEditor = BalanceEditorContext(
                            accountID: viewModel.accounts.first(where: { $0.id == position.id })?.id,
                            name: position.name,
                            initialBalance: position.balance,
                            isLiability: position.isLiability
                        )
                    }
                    .appSecondaryGlassButton()
                    .controlSize(.small)
                }
                .padding(.vertical, 6)
            }
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private func goalsSection(_ snapshot: FinancialPlanningSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack {
                Label(LocalizedStringKey("Savings Goals"), systemImage: "archivebox.fill")
                    .font(AppTypography.sectionTitle)
                Spacer()
                Button(LocalizedStringKey("New Goal")) {
                    isShowingGoalEditor = true
                }
                .appPrimaryGlassButton()
            }

            if snapshot.goals.isEmpty {
                Text(LocalizedStringKey("Create your first savings goal to separate emergency savings, investments or planned purchases."))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.goals) { goal in
                    SavingsGoalRow(
                        goal: goal,
                        renderAmount: renderAmount,
                        renderDate: { date in
                            appLanguage.format(date: date, dateStyle: .medium, timeStyle: .none)
                        },
                        onDelete: { viewModel.deleteGoal(using: appContainer, id: goal.id) }
                    )
                }
            }
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private func projectionSection(_ snapshot: FinancialPlanningSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            Label(LocalizedStringKey("Projection"), systemImage: "chart.line.uptrend.xyaxis")
                .font(AppTypography.sectionTitle)
            HStack(spacing: AppLayoutMetrics.contentGap) {
                PositionValue(title: "Recurring monthly saving", value: renderAmount(snapshot.monthlySavingsAverage), tint: AppColors.income)
                PositionValue(title: "Balance in 12 months", value: renderAmount(snapshot.projectedBalance12Months), tint: AppColors.neutral)
                PositionValue(title: "Free balance in 12 months", value: renderAmount(snapshot.projectedAvailableBalance12Months), tint: AppColors.warning)
            }
            Text(LocalizedStringKey("Projection uses the average net saving from available history and planned goal contributions. It is a scenario, not a guaranteed bank balance."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.panelGroup)
    }

    private func renderAmount(_ value: Decimal) -> String {
        value.privacyFormatted(hidden: privacyStoredValue, language: appLanguage)
    }
}

private struct PositionValue: View {
    let title: LocalizedStringKey
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppLayoutMetrics.contentGap)
        .padding(.vertical, 14)
        .liquidGlassPill(padding: 0, tint: tint)
    }
}

private struct SavingsGoalRow: View {
    let goal: SavingsGoalProjection
    let renderAmount: (Decimal) -> String
    let renderDate: (Date) -> String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppLayoutMetrics.contentGap) {
            Image(systemName: iconName)
                .frame(width: 30, height: 30)
                .liquidGlassPill(padding: 0, tint: AppColors.neutral)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(goal.name)
                        .font(.headline)
                    Spacer()
                    Text(renderAmount(goal.projectedAmount))
                        .font(.headline.weight(.semibold))
                }
                ProgressView(value: goal.progress)
                    .tint(goal.isOnTrack ? AppColors.income : AppColors.warning)
                HStack {
                    Text("\(renderAmount(goal.allocatedAmount)) / \(renderAmount(goal.targetAmount))")
                    if let targetDate = goal.targetDate {
                        Text("• \(renderDate(targetDate))")
                    }
                    Spacer()
                    Text(goal.isOnTrack ? LocalizedStringKey("On track") : LocalizedStringKey("Needs more saving"))
                        .foregroundStyle(goal.isOnTrack ? AppColors.income : AppColors.warning)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AppColors.expense)
        }
        .padding(.vertical, 6)
    }

    private var iconName: String {
        switch goal.kind {
        case .emergency: return "cross.case.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .travel: return "airplane"
        case .home: return "house.fill"
        case .other: return "archivebox.fill"
        }
    }
}

private struct BalanceEditorContext: Identifiable {
    let id = UUID()
    let accountID: UUID?
    let name: String
    let initialBalance: Decimal
    let isLiability: Bool
}

private struct BalanceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let context: BalanceEditorContext
    let renderAmount: (Decimal) -> String
    let onSave: (BalanceEditorContext, String, Bool) -> Void
    @State private var balanceText: String
    @State private var isLiability: Bool

    init(
        context: BalanceEditorContext,
        renderAmount: @escaping (Decimal) -> String,
        onSave: @escaping (BalanceEditorContext, String, Bool) -> Void
    ) {
        self.context = context
        self.renderAmount = renderAmount
        self.onSave = onSave
        _balanceText = State(initialValue: NSDecimalNumber(decimal: context.initialBalance).stringValue)
        _isLiability = State(initialValue: context.isLiability)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(LocalizedStringKey("Confirm current balance"))
                .font(.title2.weight(.semibold))
            Text(context.name)
                .foregroundStyle(.secondary)
            TextField(LocalizedStringKey("Amount"), text: $balanceText)
                .textFieldStyle(.roundedBorder)
            Toggle(LocalizedStringKey("This is a liability or debt"), isOn: $isLiability)
            HStack {
                Spacer()
                Button(LocalizedStringKey("Cancel")) { dismiss() }
                Button(LocalizedStringKey("Save")) {
                    onSave(context, balanceText, isLiability)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 420)
    }
}

private struct SavingsGoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, SavingsGoalKind, String, String, String, Date?) -> Void
    @State private var name = ""
    @State private var kind: SavingsGoalKind = .emergency
    @State private var target = ""
    @State private var allocated = "0"
    @State private var monthly = "0"
    @State private var targetDate = Date().addingTimeInterval(365 * 24 * 60 * 60)

    var body: some View {
        Form {
            TextField(LocalizedStringKey("Name"), text: $name)
            Picker(LocalizedStringKey("Type"), selection: $kind) {
                ForEach(SavingsGoalKind.allCases) { kind in
                    Text(kindTitle(kind)).tag(kind)
                }
            }
            TextField(LocalizedStringKey("Target amount"), text: $target)
            TextField(LocalizedStringKey("Already assigned"), text: $allocated)
            TextField(LocalizedStringKey("Monthly contribution"), text: $monthly)
            DatePicker(LocalizedStringKey("Target date"), selection: $targetDate, displayedComponents: .date)
            HStack {
                Spacer()
                Button(LocalizedStringKey("Cancel")) { dismiss() }
                Button(LocalizedStringKey("Save")) {
                    onSave(name, kind, target, allocated, monthly, targetDate)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .frame(width: 480)
    }

    private func kindTitle(_ kind: SavingsGoalKind) -> String {
        switch kind {
        case .emergency: return String(localized: "Emergency fund")
        case .investment: return String(localized: "Investment")
        case .travel: return String(localized: "Travel")
        case .home: return String(localized: "Home")
        case .other: return String(localized: "Other")
        }
    }
}
