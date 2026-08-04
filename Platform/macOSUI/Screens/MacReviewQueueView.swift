import SwiftUI

struct MacReviewQueueView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled = false
    @State private var viewModel = ReviewQueueViewModel()
    @State private var isAdvancedExpanded = false

    var body: some View {
        HSplitView {
            reviewList
            inspector
                .frame(minWidth: 340, idealWidth: AppLayoutMetrics.maxInspectorWidth)
        }
        .navigationTitle(LocalizedStringKey("Review Queue"))
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button {
                        Task {
                            await viewModel.recategorizeAllPending(using: appContainer)
                        }
                    } label: {
                        if viewModel.isRecategorizing {
                            Label(LocalizedStringKey("Re-categorizing…"), systemImage: "hourglass")
                        } else {
                            Label(LocalizedStringKey("Re-categorize with ML"), systemImage: "sparkles")
                        }
                    }
                    .disabled(viewModel.isRecategorizing || viewModel.transactions.isEmpty)

                    Divider()

                    Button(LocalizedStringKey("Accept high-confidence suggestions")) {
                        viewModel.acceptAllHighConfidenceSuggestions(using: appContainer)
                    }
                    .disabled(viewModel.transactions.allSatisfy { !$0.hasRecategorizationSuggestion })
                } label: {
                    Label(LocalizedStringKey("Review Actions"), systemImage: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            viewModel.load(using: appContainer)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            viewModel.load(using: appContainer)
        }
        .onKeyPress(.return) {
            viewModel.approveSelected(using: appContainer)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.skipSelected()
            return .handled
        }
    }

    private var reviewList: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            listHeader

            if let summary = viewModel.recategorizationSummary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.blue)
                    .padding(AppLayoutMetrics.contentGap)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
            }

            if viewModel.transactions.isEmpty {
                Spacer()
                EmptyStateView(
                    title: LocalizedStringKey("Review Queue Empty"),
                    message: LocalizedStringKey("All imported transactions are categorized or there are no imports yet."),
                    systemImage: "checklist"
                )
                Spacer()
            } else if viewModel.filteredList.isEmpty {
                Spacer()
                ContentUnavailableView(
                    LocalizedStringKey("No results"),
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(LocalizedStringKey("No movements match the selected filter."))
                )
                Spacer()
            } else {
                listContent
            }
        }
        .padding(AppLayoutMetrics.sectionGap)
        .background(AppMaterials.sidebar, in: Rectangle())
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("Review Queue"))
                        .font(AppTypography.sectionTitle)
                    Text(String(localized: "\(viewModel.pendingCount) pending"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            FloatingGlassSegmentedBar(
                options: ReviewListFilter.allCases,
                title: { $0.title },
                selection: $viewModel.listFilter
            )
            .frame(maxWidth: 420, alignment: .leading)
        }
    }

    private var listContent: some View {
        List(selection: Binding(
            get: { viewModel.selectedTransaction?.id },
            set: { selectedID in
                if let selectedID,
                   let transaction = viewModel.filteredList.first(where: { $0.id == selectedID }) {
                    viewModel.select(transaction)
                }
            }
        )) {
            if !viewModel.suggestedGroups.isEmpty && viewModel.listFilter == .all {
                Section(LocalizedStringKey("Suggested Batches")) {
                    ForEach(viewModel.suggestedGroups) { group in
                        Button {
                            if let transaction = viewModel.filteredList.first(where: { $0.id == group.representativeTransactionID }) {
                                viewModel.select(transaction)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                                Text(group.title)
                                    .lineLimit(1)
                                Text(String(localized: "\(group.count) similar pending movements"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section(String(localized: "Pending · \(viewModel.filteredList.count)")) {
                ForEach(viewModel.filteredList) { transaction in
                    transactionRow(transaction)
                        .tag(transaction.id)
                        .contextMenu {
                            Button(LocalizedStringKey("Approve Suggestion")) {
                                viewModel.select(transaction)
                                if transaction.hasRecategorizationSuggestion {
                                    viewModel.acceptSuggestedCategory(using: appContainer)
                                } else {
                                    viewModel.approveSelected(using: appContainer)
                                }
                            }
                            .disabled(transaction.categoryID == nil && !transaction.hasRecategorizationSuggestion)
                            if transaction.hasRecategorizationSuggestion {
                                Button(LocalizedStringKey("Dismiss Category Suggestion")) {
                                    viewModel.select(transaction)
                                    viewModel.dismissSuggestedCategory(using: appContainer)
                                }
                            }
                            Button(LocalizedStringKey("Mark as Transfer")) {
                                viewModel.select(transaction)
                                viewModel.markAsTransfer(using: appContainer)
                            }
                            Button(LocalizedStringKey("Skip")) {
                                viewModel.select(transaction)
                                viewModel.skipSelected()
                            }
                        }
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func transactionRow(_ transaction: Transaction) -> some View {
        HStack(alignment: .top, spacing: AppLayoutMetrics.contentGap) {
            confidenceBar(transaction.confidence)

            VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                HStack(alignment: .firstTextBaseline) {
                    Text(transaction.rawDescription)
                        .lineLimit(1)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(transaction.amount.privacyFormatted(hidden: isPrivacyModeEnabled, currencyCode: transaction.currencyCode))
                        .font(AppTypography.amount)
                        .foregroundStyle(transaction.amount < 0 ? .red : .green)
                }

                HStack {
                    Text(transaction.bookingDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    confidenceLabel(transaction.confidence)
                }

                HStack {
                    if transaction.hasRecategorizationSuggestion {
                        suggestionBadge(for: transaction)
                    } else {
                        categoryBadge(categoryID: transaction.categoryID)
                    }
                    Spacer()
                    Text(transaction.resolvedKind.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, AppLayoutMetrics.microGap)
    }

    private var inspector: some View {
        GlassInspectorPanel(title: LocalizedStringKey("Review Inspector"), isAdvancedExpanded: $isAdvancedExpanded) {
            if let transaction = viewModel.selectedTransaction {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
                    primaryInfo(for: transaction)
                    confidenceSection(for: transaction)
                    categorySection
                    movementTypeSection
                }
            } else {
                ContentUnavailableView(
                    LocalizedStringKey("No selection"),
                    systemImage: "cursorarrow.click",
                    description: Text(LocalizedStringKey("Select a pending transaction to confirm or correct its category."))
                )
                .frame(maxWidth: .infinity, minHeight: 280)
            }
        } advanced: {
            advancedInspectorContent
        } footer: {
            inspectorActionStrip
        }
    }

    private func primaryInfo(for transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            infoBlock(LocalizedStringKey("Concept"), transaction.rawDescription)
            infoBlock(LocalizedStringKey("Date"), transaction.bookingDate.formatted(date: .complete, time: .omitted))
            infoBlock(LocalizedStringKey("Amount"), transaction.amount.privacyFormatted(hidden: isPrivacyModeEnabled, currencyCode: transaction.currencyCode))
            infoBlock(LocalizedStringKey("Current Category"), categoryName(for: transaction.categoryID))
            if transaction.hasRecategorizationSuggestion {
                infoBlock(
                    LocalizedStringKey("Suggested Category"),
                    "\(categoryName(for: transaction.suggestedCategoryID)) · \((transaction.suggestedConfidence ?? 0).formatted(.percent.precision(.fractionLength(0))))"
                )
            }
            infoBlock(LocalizedStringKey("Source"), String(localized: LocalizedStringResource(stringLiteral: transaction.categorizationSourceRaw)))
            infoBlock(
                LocalizedStringKey("Explanation"),
                transaction.suggestedReason ?? transaction.categorizationReason ?? String(localized: "No explanation available")
            )
        }
        .contentCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.inner)
    }

    private func confidenceSection(for transaction: Transaction) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            Text(LocalizedStringKey("Confidence"))
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: transaction.confidence)
                .tint(confidenceColor(transaction.confidence))
            Text(transaction.confidence.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption2)
                .foregroundStyle(confidenceColor(transaction.confidence))
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            Text(LocalizedStringKey("Assign Category"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(LocalizedStringKey("Assign Category"), selection: Binding(
                get: { viewModel.selectedCategoryID },
                set: { viewModel.selectedCategoryID = $0 }
            )) {
                Text(LocalizedStringKey("Keep suggestion")).tag(Optional<UUID>.none)
                ForEach(viewModel.categories, id: \.id) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            .labelsHidden()
        }
    }

    private var movementTypeSection: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            Text(LocalizedStringKey("Movement Type"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(LocalizedStringKey("Movement Type"), selection: $viewModel.selectedKind) {
                Text(LocalizedStringKey("Expense")).tag(TransactionKind.expense)
                Text(LocalizedStringKey("Income")).tag(TransactionKind.income)
                Text(LocalizedStringKey("Transfer")).tag(TransactionKind.transfer)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var advancedInspectorContent: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            if let transaction = viewModel.selectedTransaction {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
                    Button(LocalizedStringKey("Mark as Transfer")) {
                        viewModel.markAsTransfer(using: appContainer)
                    }
                    .appSecondaryGlassButton()

                    if transaction.hasRecategorizationSuggestion {
                        Button(LocalizedStringKey("Accept Category Suggestion")) {
                            viewModel.acceptSuggestedCategory(using: appContainer)
                        }
                        .buttonStyle(.glassProminent)

                        Button(LocalizedStringKey("Dismiss Category Suggestion")) {
                            viewModel.dismissSuggestedCategory(using: appContainer)
                        }
                        .appSecondaryGlassButton()
                    }

                    Button(viewModel.isLoadingAISuggestion ? String(localized: "Asking AI…") : String(localized: "Ask AI Copilot")) {
                        Task { await viewModel.requestAISuggestion(using: appContainer) }
                    }
                    .appSecondaryGlassButton()
                    .disabled(viewModel.isLoadingAISuggestion)

                    Button(LocalizedStringKey("Update Type")) {
                        viewModel.updateSelectedKind(using: appContainer)
                    }
                    .appSecondaryGlassButton()

                    Toggle(LocalizedStringKey("Create rule from this correction"), isOn: $viewModel.createRuleFromCorrection)

                    if !viewModel.similarTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                            Text(String(localized: "\(viewModel.similarTransactions.count) similar pending movements"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(LocalizedStringKey("Apply Category to Similar")) {
                                viewModel.applyToSimilar(using: appContainer)
                            }
                            .appSecondaryGlassButton()
                        }
                    }

                    VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                        Text(LocalizedStringKey("New Category"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(LocalizedStringKey("Category name"), text: $viewModel.newCategoryName)
                            .textFieldStyle(.roundedBorder)
                        Toggle(LocalizedStringKey("Income category"), isOn: $viewModel.newCategoryIsIncome)
                        Button(LocalizedStringKey("Create Category")) {
                            viewModel.createCategory(using: appContainer)
                        }
                        .appSecondaryGlassButton()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(padding: AppLayoutMetrics.contentGap, radius: AppRadius.inner)

                if let _ = Optional(transaction) {
                    feedbackMessages
                }
            } else {
                Text(LocalizedStringKey("Advanced tools appear when a movement is selected."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inspectorActionStrip: some View {
        GlassActionStrip {
            PrimaryButton(title: "Approve ↵") {
                viewModel.approveSelected(using: appContainer)
            }
            PrimaryButton(title: LocalizedStringKey("Reassign")) {
                viewModel.reassignSelected(using: appContainer)
            }
        } secondary: {
            Button("Skip →") {
                viewModel.skipSelected()
            }
            .appSecondaryGlassButton()
            .foregroundStyle(.secondary)
        }
        .disabled(viewModel.selectedTransaction == nil)
    }

    private var feedbackMessages: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func infoBlock(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppTypography.body)
        }
    }

    private func confidenceBar(_ confidence: Double) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(confidenceColor(confidence))
            .frame(width: 4)
            .frame(minHeight: 42)
    }

    private func confidenceLabel(_ confidence: Double) -> some View {
        Text(confidence.formatted(.percent.precision(.fractionLength(0))))
            .font(.caption2)
            .foregroundStyle(confidenceColor(confidence))
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case AppConfig.softAutoCategorizationThreshold...: return .green
        case AppConfig.suggestionThreshold..<AppConfig.softAutoCategorizationThreshold: return .orange
        default: return .red
        }
    }

    private func categoryBadge(categoryID: UUID?) -> some View {
        Group {
            if let categoryID,
               let category = viewModel.categories.first(where: { $0.id == categoryID }) {
                Text(category.name)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                    .foregroundStyle(.secondary)
            } else {
                Text(LocalizedStringKey("Uncategorized"))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func suggestionBadge(for transaction: Transaction) -> some View {
        HStack(spacing: 4) {
            Text(categoryName(for: transaction.categoryID))
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
            Text(categoryName(for: transaction.suggestedCategoryID))
                .foregroundStyle(.green)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.green.opacity(0.12), in: Capsule())
    }

    private func categoryName(for categoryID: UUID?) -> String {
        guard let categoryID,
              let category = viewModel.categories.first(where: { $0.id == categoryID }) else {
            return String(localized: "Uncategorized")
        }
        return category.name
    }
}
