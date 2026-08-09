import SwiftUI
import UniformTypeIdentifiers

struct MacImportsView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .english
    @State private var viewModel = ImportViewModel()
    @State private var importTrigger = 0
    @State private var isFileImporterPresented = false
    @State private var recentImports: [ImportBatch] = []
    @State private var isAdvancedValidationExpanded = false
    @State private var isRecentImportsExpanded = false

    let openTransactions: () -> Void

    private var currentStep: ImportFlowStep {
        if viewModel.summary != nil || viewModel.isImporting {
            return .importing
        }
        if !viewModel.previewRows.isEmpty || viewModel.diagnostics != nil || viewModel.manualMapping != nil {
            return .validate
        }
        return .file
    }

    private var primaryActionTitle: LocalizedStringKey {
        if viewModel.summary != nil {
            return "Open Transactions"
        }
        if !viewModel.previewRows.isEmpty {
            return "Run Import"
        }
        if viewModel.selectedFileURL != nil || !viewModel.csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Preview Import"
        }
        return "Choose File"
    }

    var body: some View {
        GlassPageScaffold {
            header
        } content: {
            VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                stepBar
                primaryActionStrip

                switch currentStep {
                case .file:
                    fileStage
                case .validate:
                    validateStage
                case .importing:
                    importStage
                }

                feedbackMessages

                recentImportsSection
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(LocalizedStringKey("Recent Imports")) {
                    loadRecentImports()
                    isRecentImportsExpanded = true
                }
                Button(LocalizedStringKey("Open Transactions")) {
                    openTransactions()
                }
                .disabled(recentImports.isEmpty && viewModel.summary == nil)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .spreadsheet, .pdf]
        ) { result in
            switch result {
            case .success(let url):
                viewModel.loadFile(from: url, using: appContainer, language: appLanguage)
                loadRecentImports()
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: Binding(
            get: { viewModel.summary.map(ImportSummaryItem.init) },
            set: { item in viewModel.summary = item?.summary }
        )) { item in
            ImportSummarySheet(summary: item.summary) {
                viewModel.summary = nil
                openTransactions()
            }
        }
        .onAppear {
            loadRecentImports()
        }
        .task(id: importTrigger) {
            guard importTrigger > 0 else { return }
            await viewModel.importTransactions(using: appContainer, language: appLanguage)
            loadRecentImports()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            Text(LocalizedStringKey("Imports"))
                .font(AppTypography.displayTitle)
            Text(LocalizedStringKey("Bring in a bank export, validate the structure, then run a single clear import path."))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey("Recognized headers include Fecha, F. valor, Fecha cble, Fecha valor, Concepto, Concepto ampliado, Importe, Moneda and Saldo."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var stepBar: some View {
        HStack(spacing: AppLayoutMetrics.contentGap) {
            ForEach(ImportFlowStep.allCases) { step in
                HStack(spacing: AppLayoutMetrics.microGap) {
                    Image(systemName: step == currentStep ? "circle.inset.filled" : "circle")
                        .foregroundStyle(stepTint(step))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.headline)
                        Text(step.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppLayoutMetrics.contentGap)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .fill(step == currentStep ? AppColors.cardBackground.opacity(1.15) : AppColors.cardBackground)
                )
            }
        }
    }

    private var primaryActionStrip: some View {
        GlassActionStrip {
            PrimaryButton(title: primaryActionTitle) {
                performPrimaryAction()
            }
        } secondary: {
            if currentStep == .validate {
                Button(LocalizedStringKey("Choose Another File")) {
                    isFileImporterPresented = true
                }
                .appSecondaryGlassButton()
            } else if currentStep == .importing, viewModel.summary != nil {
                Button(LocalizedStringKey("Import Another File")) {
                    isFileImporterPresented = true
                }
                .appSecondaryGlassButton()
            } else {
                Button(LocalizedStringKey("Recent Imports")) {
                    loadRecentImports()
                    isRecentImportsExpanded = true
                }
                .appSecondaryGlassButton()
            }
        }
    }

    private var fileStage: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            ImportDropZone(
                isTargeted: $viewModel.isDropTargeted,
                onChooseFile: { isFileImporterPresented = true },
                onDroppedURLs: { urls in
                    guard let url = urls.first else { return }
                    viewModel.loadFile(from: url, using: appContainer, language: appLanguage)
                    loadRecentImports()
                }
            )

            accountContextCard

            if viewModel.selectedFileURL != nil || !viewModel.sourceFileName.isEmpty {
                fileSummaryBand
            }
        }
    }

    private var validateStage: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            fileSummaryBand
            accountContextCard
            previewSection

            if !viewModel.invalidRows.isEmpty {
                issuesSection
            }

            if viewModel.diagnostics != nil || (viewModel.manualMapping != nil && !viewModel.availableHeaders().isEmpty) {
                DisclosureGroup(isExpanded: $isAdvancedValidationExpanded) {
                    VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
                        if let diagnostics = viewModel.diagnostics {
                            diagnosticsPanel(diagnostics)
                        }

                        if let mapping = viewModel.manualMapping, !viewModel.availableHeaders().isEmpty {
                            manualMappingSection(mapping)
                        }
                    }
                    .padding(.top, AppLayoutMetrics.contentGap)
                } label: {
                    Label(LocalizedStringKey("Advanced Validation"), systemImage: "slider.horizontal.3")
                        .font(AppTypography.sectionTitle)
                }
                .padding(AppLayoutMetrics.contentGap)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .fill(AppMaterials.contentMaterial)
                )
            }
        }
    }

    private var accountContextCard: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            Label(LocalizedStringKey("Import account"), systemImage: "building.columns")
                .font(AppTypography.sectionTitle)
            Text(LocalizedStringKey("Associate these movements with an account to keep balances and transfers reliable."))
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField(LocalizedStringKey("Account name, for example Main account"), text: $viewModel.accountName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }

    private var importStage: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            progressPanel
            importSummaryBand

            if !viewModel.previewRows.isEmpty {
                previewSection
            }
        }
    }

    private var fileSummaryBand: some View {
        HStack(alignment: .top, spacing: AppLayoutMetrics.contentGap) {
            summaryStat(
                title: LocalizedStringKey("Selected file"),
                value: viewModel.selectedFileURL?.lastPathComponent ?? viewModel.sourceFileName,
                subtitleText: Text(verbatim: detectedSourceType)
            )
            summaryStat(
                title: LocalizedStringKey("Preview rows"),
                value: viewModel.previewRows.isEmpty ? String(localized: "Waiting") : "\(viewModel.previewRows.count)",
                subtitleText: Text(LocalizedStringKey("Rows ready for validation"))
            )
            summaryStat(
                title: LocalizedStringKey("Pending review"),
                value: pendingReviewValue,
                subtitleText: Text(LocalizedStringKey("Movements likely to need attention"))
            )
        }
        .contentCard()
    }

    private var importSummaryBand: some View {
        HStack(alignment: .top, spacing: AppLayoutMetrics.contentGap) {
            summaryStat(
                title: LocalizedStringKey("Last import"),
                value: viewModel.summary?.sourceFileName ?? viewModel.lastImportedFileName ?? String(localized: "In progress"),
                subtitleText: Text(LocalizedStringKey("Current import context"))
            )
            summaryStat(
                title: LocalizedStringKey("Detected accounts"),
                value: viewModel.summary.map { "\($0.detectedAccounts)" } ?? "0",
                subtitleText: Text(LocalizedStringKey("Accounts found in source"))
            )
            summaryStat(
                title: LocalizedStringKey("Pending review"),
                value: pendingReviewValue,
                subtitleText: Text(LocalizedStringKey("Items queued for confirmation"))
            )
        }
        .contentCard()
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            Text(LocalizedStringKey(viewModel.isImporting ? "Import in progress" : "Import ready"))
                .font(AppTypography.sectionTitle)

            ProgressView(value: viewModel.isImporting ? viewModel.importProgress : 1.0, total: 1.0)

            Text(LocalizedStringKey(viewModel.isImporting ? "Categorizing movements and preparing the final summary." : "The import finished. Open Transactions to review the results."))
                .foregroundStyle(.secondary)

            if viewModel.isImporting {
                Button(LocalizedStringKey("Cancel"), role: .cancel) {
                    viewModel.cancelImport()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            Text(LocalizedStringKey("Preview"))
                .font(AppTypography.sectionTitle)

            if viewModel.previewRows.isEmpty {
                Text(LocalizedStringKey("Choose a CSV or XLSX bank export to preview imported movements."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                Table(viewModel.previewRows) {
                    TableColumn(LocalizedStringKey("Row")) { row in
                        Text("\(row.rowNumber)")
                    }
                    TableColumn(LocalizedStringKey("Date")) { row in
                        Text(row.bookingDate.formatted(date: .numeric, time: .omitted))
                    }
                    TableColumn(LocalizedStringKey("Concept")) { row in
                        Text(row.concept)
                            .lineLimit(1)
                    }
                    TableColumn(LocalizedStringKey("Amount")) { row in
                        Text(row.amount.formatted(.currency(code: row.currencyCode ?? "EUR")))
                    }
                    TableColumn(LocalizedStringKey("Balance")) { row in
                        Text(row.balance?.formatted(.currency(code: row.currencyCode ?? "EUR")) ?? "-")
                    }
                    TableColumn(LocalizedStringKey("Status")) { row in
                        Text(LocalizedStringKey(row.status.rawValue.uppercased()))
                            .foregroundStyle(row.status == .ok ? .green : .orange)
                    }
                }
                .frame(minHeight: 320)
                .contentCard(padding: AppLayoutMetrics.microGap)
            }
        }
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            Text(LocalizedStringKey("Import Issues"))
                .font(AppTypography.sectionTitle)

            ForEach(viewModel.invalidRows.prefix(12)) { issue in
                VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
                    HStack {
                        Text(String(localized: "Row \(issue.rowNumber)"))
                            .font(.caption.weight(.semibold))
                        Text(LocalizedStringKey(issue.severity.rawValue.uppercased()))
                            .font(.caption)
                            .foregroundStyle(issue.severity == .error ? .red : .orange)
                    }

                    Text(issue.message)

                    if !issue.rawValuesSummary.isEmpty {
                        Text(issue.rawValuesSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
        }
    }

    private var feedbackMessages: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.green)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    private var recentImportsSection: some View {
        DisclosureGroup(isExpanded: $isRecentImportsExpanded) {
            RecentImportsList(sessions: recentImports)
                .padding(.top, AppLayoutMetrics.contentGap)
        } label: {
            Label(LocalizedStringKey("Recent Imports"), systemImage: "clock.arrow.circlepath")
                .font(AppTypography.sectionTitle)
        }
        .padding(AppLayoutMetrics.contentGap)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppMaterials.contentMaterial)
        )
    }

    private func summaryStat(title: LocalizedStringKey, value: String, subtitleText: Text) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            subtitleText
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diagnosticsPanel(_ diagnostics: ImportDiagnostics) -> some View {
        let items = [
            DiagnosticItem(key: "Source", value: diagnostics.sourceType.uppercased()),
            DiagnosticItem(key: "Worksheet", value: diagnostics.worksheetName ?? "-"),
            DiagnosticItem(key: "Delimiter", value: diagnostics.delimiter ?? "-"),
            DiagnosticItem(key: "Header Row", value: diagnostics.headerRowIndex.map { String($0 + 1) } ?? "-"),
            DiagnosticItem(key: "Mapped Columns", value: diagnostics.mappedColumnsDescription ?? "-"),
            DiagnosticItem(key: "Raw Rows", value: "\(diagnostics.rawRowCount)"),
            DiagnosticItem(key: "Valid Rows", value: "\(diagnostics.validRowCount)"),
            DiagnosticItem(key: "Invalid Rows", value: "\(diagnostics.invalidRowCount)")
        ]

        return VStack(alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
            Text(LocalizedStringKey("Diagnostics"))
                .font(AppTypography.sectionTitle)
            Table(items) {
                TableColumn(LocalizedStringKey("Metric")) { item in
                    Text(item.key).foregroundStyle(.secondary)
                }
                TableColumn(LocalizedStringKey("Value")) { item in
                    Text(item.value)
                }
            }
            .frame(height: 220)
            .contentCard(padding: AppLayoutMetrics.microGap)
        }
    }

    private func manualMappingSection(_ mapping: ImportColumnMapping) -> some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            Text(LocalizedStringKey("Column Mapping"))
                .font(AppTypography.sectionTitle)
            Text(LocalizedStringKey("Adjust the columns only when the automatic preview is incomplete or incorrect."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 180), spacing: AppLayoutMetrics.contentGap),
                GridItem(.flexible(minimum: 180), spacing: AppLayoutMetrics.contentGap),
                GridItem(.flexible(minimum: 180), spacing: AppLayoutMetrics.contentGap)
            ], alignment: .leading, spacing: AppLayoutMetrics.contentGap) {
                ForEach(ImportColumnField.allCases) { field in
                    VStack(alignment: .leading, spacing: AppLayoutMetrics.microGap) {
                        Text(field.title + (field.isRequired ? " *" : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker(field.title, selection: Binding(
                            get: { viewModel.currentMappingIndex(for: field) ?? -1 },
                            set: { newValue in
                                viewModel.updateManualMapping(field, index: newValue < 0 ? nil : newValue, using: appContainer)
                            }
                        )) {
                            Text(LocalizedStringKey("Not Mapped")).tag(-1)
                            ForEach(Array(mapping.availableHeaders.enumerated()), id: \.offset) { index, header in
                                Text(header.isEmpty ? String(localized: "Column \(index + 1)") : header).tag(index)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
        }
        .contentCard()
    }

    private var detectedSourceType: String {
        viewModel.diagnostics?.sourceType.uppercased() ?? "Bank export"
    }

    private var pendingReviewValue: String {
        if let summary = viewModel.summary {
            return "\(summary.pendingReviewCount)"
        }
        return "\(viewModel.invalidRows.count)"
    }

    private func stepTint(_ step: ImportFlowStep) -> Color {
        if step == currentStep {
            return AppColors.accent
        }
        if step.rawValue < currentStep.rawValue {
            return AppColors.income
        }
        return .secondary
    }

    private func performPrimaryAction() {
        if viewModel.summary != nil {
            openTransactions()
            return
        }

        if !viewModel.previewRows.isEmpty {
            importTrigger += 1
            return
        }

        if viewModel.selectedFileURL != nil || !viewModel.csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.preview(using: appContainer, language: appLanguage)
            return
        }

        isFileImporterPresented = true
    }

    private func loadRecentImports() {
        recentImports = (try? appContainer.importBatchRepository.fetchRecentBatches()) ?? []
    }

    private struct DiagnosticItem: Identifiable {
        let id = UUID()
        let key: String
        let value: String
    }
}

private enum ImportFlowStep: Int, CaseIterable, Identifiable {
    case file
    case validate
    case importing

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .file: return String(localized: "File")
        case .validate: return String(localized: "Validate")
        case .importing: return String(localized: "Import")
        }
    }

    var subtitle: String {
        switch self {
        case .file: return String(localized: "Choose the source")
        case .validate: return String(localized: "Preview and verify")
        case .importing: return String(localized: "Run and review")
        }
    }
}

private struct ImportSummaryItem: Identifiable {
    let summary: ImportSummary
    var id: String { summary.sourceFileName + "-\(summary.importedCount)-\(summary.duplicatesSkipped)" }
}
