import XCTest
import SwiftData
@testable import FinanceCategorizerIOS

private struct UnavailableAIAvailabilityServiceStub: AIAvailabilityChecking {
    func isAvailable() -> Bool { false }
}

@MainActor
final class FinanceCategorizerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(AppLanguage.spanish.rawValue, forKey: "appLanguage")
    }

    func testAppConfigThresholdsAreOrdered() {
        XCTAssertGreaterThan(AppConfig.autoCategorizationThreshold, AppConfig.softAutoCategorizationThreshold)
        XCTAssertGreaterThan(AppConfig.softAutoCategorizationThreshold, AppConfig.suggestionThreshold)
    }

    func testLocalizedStringFilesHaveTheSameKeys() throws {
        let englishKeys = try localizationKeys(in: projectRootURL().appendingPathComponent("Resources/en.lproj/Localizable.strings"))
        let spanishKeys = try localizationKeys(in: projectRootURL().appendingPathComponent("Resources/es.lproj/Localizable.strings"))
        let trackedKeys = [
            "import.error.chooseSource",
            "import.status.imported",
            "import.error.duplicateFile",
            "settings.ml.ready.title",
            "settings.ml.learning.detail",
            "localModel.profileSummary.updated",
            "review.status.aiSuggests",
            "review.status.mlRerun",
            "dashboard.copilot.summaryPositive",
            "dashboard.confidence.coverage",
            "appleAI.intent.monthlyBriefing.title",
            "appleAI.intent.learningReadiness.subtitle",
            "appleAI.currentScreen",
            "appleAI.regenerate",
            "recentImports.rows",
            "importSummary.openImportedTransactions",
            "ruleEditor.assignCategory",
            "importDropZone.dropHere",
            "transactions.recategorizeSelectedType",
            "categories.groupCount",
            "insights.pendingCount"
        ]

        for key in trackedKeys {
            XCTAssertTrue(englishKeys.contains(key), "Missing English key: \(key)")
            XCTAssertTrue(spanishKeys.contains(key), "Missing Spanish key: \(key)")
        }
    }

    func testTransactionNormalizerCleansNoiseAndBuildsFingerprint() {
        let normalizer = TransactionNormalizer()
        let row = ParsedRowDTO(
            externalID: "row-1",
            bookingDate: Date(timeIntervalSince1970: 1_700_000_000),
            valueDate: nil,
            description: "COMPRA TARJ SEPA MERCADONA VALENCIA 123456",
            amount: Decimal(-42.60),
            currencyCode: "EUR",
            accountName: "Cuenta principal"
        )

        let normalized = normalizer.normalize(row)

        XCTAssertEqual(normalized.cleanedDescription, "MERCADONA VALENCIA")
        XCTAssertEqual(normalized.merchantCanonicalName, "Mercadona")
        XCTAssertEqual(normalized.sign, -1)
        XCTAssertFalse(normalized.fingerprint.isEmpty)
    }

    func testConfidenceScoreThresholds() {
        XCTAssertTrue(ConfidenceScore(value: 0.95).shouldAutoAccept)
        XCTAssertTrue(ConfidenceScore(value: 0.81).shouldAutoAcceptButMarkSoft)
        XCTAssertTrue(ConfidenceScore(value: 0.40).shouldSendToReview)
    }

    func testCSVPreviewDetectsSemicolonDelimitedBankExport() throws {
        let csv = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;S/ORD.TRANSFERENCIA Garage;-50,92;1.200,33
        03/01/2026;03/01/2026;SEPA 600238298472;-500,92;699,41
        """

        let preview = try CSVParsingService().preview(text: csv)

        XCTAssertFalse(preview.requiresManualMapping)
        XCTAssertEqual(preview.rows.count, 2)
        XCTAssertTrue(preview.invalidRows.isEmpty)
        XCTAssertEqual(preview.rows.first?.amount, Decimal(string: "-50.92"))
    }

    func testBankHeaderDetectionRejectsTransactionRows() {
        let rows = [
            ["02/01/2026", "02/01/2026", "S/ORD.TRANSFERENCIA Garage", "-50,92", "1.200,33"],
            ["03/01/2026", "03/01/2026", "SEPA 600238298472", "-500,92", "699,41"]
        ]

        XCTAssertNil(BankColumnAutoMapper().detectHeaderCandidate(in: rows))
    }

    func testCSVPreviewMergesExtraSemicolonsIntoConceptColumn() throws {
        let csv = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;TRANSFERENCIA;ALQUILER ENERO;-500,00;9387,92
        """

        let preview = try CSVParsingService().preview(text: csv)

        XCTAssertEqual(preview.rows.count, 1)
        XCTAssertEqual(preview.invalidRows.count, 0)
        XCTAssertEqual(preview.rows.first?.concept, "TRANSFERENCIA ALQUILER ENERO")
        XCTAssertEqual(preview.rows.first?.amount, Decimal(string: "-500.00"))
    }

    func testCSVPreviewSupportsQuotedMultilineConcepts() throws {
        let csv = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;"S/ORD.TRANSFERENCIA Garage
        SEPA 600238298472             Jose Luis Ahullana";-50,92;9887,92
        """

        let preview = try CSVParsingService().preview(text: csv)

        XCTAssertEqual(preview.rows.count, 1)
        XCTAssertTrue(preview.invalidRows.isEmpty)
        XCTAssertTrue(preview.rows.first?.concept.contains("S/ORD.TRANSFERENCIA Garage") == true)
        XCTAssertTrue(preview.rows.first?.concept.contains("Jose Luis Ahullana") == true)
        XCTAssertEqual(preview.rows.first?.amount, Decimal(string: "-50.92"))
    }

    func testCSVPreviewDoesNotCollapseWholeFileWhenQuotesAppearInsideField() throws {
        let csv = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;RECIBO AXA \"SEGUROS\" GENERALES;-50,92;9887,92
        03/01/2026;03/01/2026;TRASPASO;-500,00;9387,92
        """

        let preview = try CSVParsingService().preview(text: csv)

        XCTAssertEqual(preview.diagnostics.rawRowCount, 3)
        XCTAssertEqual(preview.rows.count, 2)
    }

    func testRealBankCSVWithMultilineConceptsBuildsPreview() throws {
        let url = unitTestFixtureURL("openbank/openbank_csv_multiline.csv")
        let csv = try String(contentsOf: url, encoding: .utf8)

        let preview = try CSVParsingService().preview(text: csv)

        XCTAssertEqual(preview.diagnostics.rawRowCount, 4)
        XCTAssertEqual(preview.rows.count, 3)
        XCTAssertNotNil(preview.mapping)
        XCTAssertFalse(preview.requiresManualMapping)
        let firstRow = try XCTUnwrap(preview.rows.first)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: firstRow.bookingDate), 2026)
        XCTAssertEqual(calendar.component(.month, from: firstRow.bookingDate), 1)
        XCTAssertEqual(calendar.component(.day, from: firstRow.bookingDate), 2)
        XCTAssertTrue(firstRow.concept.contains("MERCADONA TEST") == true)
    }

    func testImportCSVFixturePersistsBatchAndBlocksDuplicateImport() async throws {
        let container = AppContainer(inMemory: true)
        let csv = try String(contentsOf: unitTestFixtureURL("openbank/openbank_csv_multiline.csv"), encoding: .utf8)

        let summary = try await container.importOrchestrator.importCSV(
            csv,
            sourceFileName: "openbank_csv_multiline.csv",
            language: .spanish
        )

        XCTAssertEqual(summary.rawRowCount, 4)
        XCTAssertEqual(summary.validRowCount, 3)
        XCTAssertEqual(summary.importedCount, 3)
        XCTAssertEqual(try container.transactionRepository.count(), 3)
        XCTAssertEqual(try container.importBatchRepository.fetchRecentBatches(limit: 10).count, 1)

        do {
            _ = try await container.importOrchestrator.importCSV(
                csv,
                sourceFileName: "openbank_csv_multiline.csv",
                language: .spanish
            )
            XCTFail("Expected duplicate import to be blocked.")
        } catch DuplicateImportError.alreadyImported(let info) {
            XCTAssertEqual(info.previousFileName, "openbank_csv_multiline.csv")
            XCTAssertEqual(info.importedRowCount, 3)
        }
    }

    func testImportHandlesLegitimateDuplicatesInSameOrSeparateImportBatches() async throws {
        let container = AppContainer(inMemory: true)
        
        // 1. A CSV containing two identical coffee transactions on the same day.
        let csv = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;Cafeteria Test;-2,50;100,00
        02/01/2026;02/01/2026;Cafeteria Test;-2,50;97,50
        """
        
        let summary1 = try await container.importOrchestrator.importCSV(
            csv,
            sourceFileName: "batch1.csv",
            language: .spanish
        )
        
        // Both should be imported since they are distinct rows in the same batch
        XCTAssertEqual(summary1.importedCount, 2)
        XCTAssertEqual(try container.transactionRepository.count(), 2)
        
        // 2. Importing a second CSV with 1 identical coffee transaction.
        let csv2 = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;Cafeteria Test;-2,50;95,00
        """
        
        let summary2 = try await container.importOrchestrator.importCSV(
            csv2,
            sourceFileName: "batch2.csv",
            language: .spanish
        )
        
        // Should be skipped because occurrence index (1) <= database count (2)
        XCTAssertEqual(summary2.importedCount, 0)
        XCTAssertEqual(summary2.duplicatesSkipped, 1)
        XCTAssertEqual(try container.transactionRepository.count(), 2)
        
        // 3. Importing a third CSV with 3 identical coffee transactions.
        let csv3 = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;Cafeteria Test;-2,50;95,00
        02/01/2026;02/01/2026;Cafeteria Test;-2,50;92,50
        02/01/2026;02/01/2026;Cafeteria Test;-2,50;90,00
        """
        
        let summary3 = try await container.importOrchestrator.importCSV(
            csv3,
            sourceFileName: "batch3.csv",
            language: .spanish
        )
        
        // Only the 3rd occurrence should be imported (since DB count was 2, and we have occurrences 1, 2, and 3)
        XCTAssertEqual(summary3.importedCount, 1)
        XCTAssertEqual(summary3.duplicatesSkipped, 2)
        XCTAssertEqual(try container.transactionRepository.count(), 3)

        // 4. Re-importing the third CSV (3 transactions) under a different name:
        do {
            _ = try await container.importOrchestrator.importCSV(
                csv3,
                sourceFileName: "batch4.csv",
                language: .spanish
            )
            XCTFail("Expected duplicate import to be blocked.")
        } catch DuplicateImportError.alreadyImported(let info) {
            XCTAssertEqual(info.previousFileName, "batch3.csv")
            XCTAssertEqual(info.importedRowCount, 1)
        }
        XCTAssertEqual(try container.transactionRepository.count(), 3)

        // 5. Importing a new CSV that is not a duplicate file (has a new row) but contains the 3 coffee transactions:
        let csv4 = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;Cafeteria Test;-2,50;95,00
        02/01/2026;02/01/2026;Cafeteria Test;-2,50;92,50
        02/01/2026;02/01/2026;Cafeteria Test;-2,50;90,00
        02/01/2026;02/01/2026;New Legitimate Transaction;-10,00;80,00
        """

        let summary5 = try await container.importOrchestrator.importCSV(
            csv4,
            sourceFileName: "batch5.csv",
            language: .spanish
        )

        // The 3 coffee transactions should be skipped as duplicates, the new one should be imported
        XCTAssertEqual(summary5.importedCount, 1)
        XCTAssertEqual(summary5.duplicatesSkipped, 3)
        XCTAssertEqual(try container.transactionRepository.count(), 4)
    }

    func testPDFParserDoesNotAdvertiseUnimplementedBanksAsSupported() {
        let santanderText = """
        Banco Santander
        Extracto de movimientos
        02/01/2026 Compra test -10,00
        """

        XCTAssertThrowsError(try PDFParsingService().preview(text: santanderText)) { error in
            XCTAssertEqual(error as? PDFImportError, .unsupportedBankFormat)
        }
    }

    func testCSVPreviewClosesQuotedMultilineRowsIndependently() throws {
        let csv = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;"S/ORD.TRANSFERENCIA Garatge
        SEPA 600238298472                       Jose Luis Ahullana                     ";-50;9887,92
        02/01/2026;02/01/2026;"S/ORD.TRANSFERENCIA Alquiler
        SEPA 600238344996                       Javier Breso                           ";-500;9387,92
        """

        let preview = try CSVParsingService().preview(text: csv)

        XCTAssertEqual(preview.diagnostics.rawRowCount, 3)
        XCTAssertEqual(preview.rows.count, 2)
        XCTAssertEqual(preview.rows.first?.amount, Decimal(string: "-50"))
        XCTAssertEqual(preview.rows.last?.amount, Decimal(string: "-500"))
    }

    func testAmountParserHandlesEuropeanDecimalsAndNegativeFormats() {
        XCTAssertEqual(ImportValueParser.parseAmount("-1.234,56"), Decimal(string: "-1234.56"))
        XCTAssertEqual(ImportValueParser.parseAmount("1,234.56-"), Decimal(string: "-1234.56"))
        XCTAssertEqual(ImportValueParser.parseAmount("(1.234,56)"), Decimal(string: "-1234.56"))
    }

    func testCorrectionLearningCreatesRuleAndUpdatesMerchantMemory() throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let groceries = try XCTUnwrap(
            try container.categoryRepository.fetchAll().first(where: { $0.name == "Alimentacion" })
        )

        let transaction = Transaction(
            bookingDate: .now,
            rawDescription: "MERCADONA VALENCIA",
            cleanedDescription: "MERCADONA VALENCIA",
            merchantDisplayName: "Mercadona",
            merchantCanonicalName: "Mercadona",
            amount: Decimal(-10),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: "Cuenta principal",
            categoryID: nil,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.unknown.rawValue,
            confidence: 0.32,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue,
            categorizationReason: "No reliable match.",
            fingerprint: "fp-1",
            isRecurringCandidate: false
        )

        try container.transactionRepository.insert(transaction)
        try container.correctionLearningService.applyCorrection(
            for: transaction,
            categoryID: groceries.id,
            applyToFuture: true
        )

        let saved = try XCTUnwrap(try container.transactionRepository.fetch(transactionID: transaction.id))
        XCTAssertEqual(saved.categoryID, groceries.id)
        XCTAssertEqual(saved.categorizationSourceRaw, CategorizationSource.manual.rawValue)
        XCTAssertFalse(saved.needsReview)

        let merchantCategoryID = try container.merchantRepository.preferredCategoryID(for: "Mercadona")
        XCTAssertEqual(merchantCategoryID, groceries.id)
        XCTAssertEqual(try container.ruleRepository.fetchActiveRules().count, 1)
    }

    func testReviewQueueCanCreateCustomCategory() throws {
        let container = AppContainer(inMemory: true)
        let viewModel = ReviewQueueViewModel()

        viewModel.newCategoryName = "Mascotas"
        viewModel.newCategoryIsIncome = false
        viewModel.createCategory(using: container)

        let created = try container.categoryRepository.fetchAll().first { $0.name == "Mascotas" }
        XCTAssertNotNil(created)
        XCTAssertEqual(viewModel.selectedCategoryID, created?.id)
    }

    func testTransactionRepositoryCanFlipExpenseIntoIncome() throws {
        let container = AppContainer(inMemory: true)
        let transaction = Transaction(
            bookingDate: .now,
            rawDescription: "TRANSFERENCIA RECIBIDA",
            cleanedDescription: "TRANSFERENCIA RECIBIDA",
            merchantDisplayName: nil,
            merchantCanonicalName: nil,
            amount: Decimal(-120),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: "Cuenta",
            categoryID: nil,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.manual.rawValue,
            confidence: 1,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            categorizationReason: nil,
            fingerprint: "flip-1",
            isRecurringCandidate: false
        )

        try container.transactionRepository.insert(transaction)
        try container.transactionRepository.updateTransactionKind(transactionID: transaction.id, kind: .income)

        let saved = try XCTUnwrap(try container.transactionRepository.fetch(transactionID: transaction.id))
        XCTAssertEqual(saved.kindRaw, TransactionKind.income.rawValue)
        XCTAssertEqual(saved.amount, Decimal(120))
    }

    func testReviewQueueDetectsSimilarTransactionsForBatching() {
        let viewModel = ReviewQueueViewModel()
        let first = Transaction(
            bookingDate: .now,
            rawDescription: "BIZUM ENVIADO CLARA",
            cleanedDescription: "BIZUM ENVIADO CLARA",
            merchantDisplayName: "Bizum",
            merchantCanonicalName: "Bizum",
            amount: Decimal(-20),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: nil,
            categoryID: nil,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.unknown.rawValue,
            confidence: 0.2,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue,
            categorizationReason: nil,
            fingerprint: "sim-1",
            isRecurringCandidate: false
        )
        let second = Transaction(
            bookingDate: .now,
            rawDescription: "BIZUM ENVIADO CLARA MARIA",
            cleanedDescription: "BIZUM ENVIADO CLARA MARIA",
            merchantDisplayName: "Bizum",
            merchantCanonicalName: "Bizum",
            amount: Decimal(-35),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: nil,
            categoryID: nil,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.unknown.rawValue,
            confidence: 0.2,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue,
            categorizationReason: nil,
            fingerprint: "sim-2",
            isRecurringCandidate: false
        )
        let third = Transaction(
            bookingDate: .now,
            rawDescription: "NOMINA GENERALITAT",
            cleanedDescription: "NOMINA GENERALITAT",
            merchantDisplayName: "Generalitat",
            merchantCanonicalName: "Generalitat",
            amount: Decimal(1400),
            currencyCode: "EUR",
            kindRaw: TransactionKind.income.rawValue,
            accountName: nil,
            categoryID: nil,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.unknown.rawValue,
            confidence: 0.2,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue,
            categorizationReason: nil,
            fingerprint: "sim-3",
            isRecurringCandidate: false
        )

        viewModel.transactions = [first, second, third]
        viewModel.select(first)

        XCTAssertEqual(viewModel.similarTransactions.count, 1)
        XCTAssertEqual(viewModel.similarTransactions.first?.id, second.id)
    }

    func testLocalModelLearnsFromCorrectedTransactions() async throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let groceries = try XCTUnwrap(
            try container.categoryRepository.fetchAll().first(where: { $0.name == "Alimentacion" })
        )

        let first = Transaction(
            bookingDate: .now,
            rawDescription: "COMPRA MERCADONA RUZAFA",
            cleanedDescription: "MERCADONA RUZAFA",
            merchantDisplayName: "Mercadona",
            merchantCanonicalName: "Mercadona",
            amount: Decimal(-22.50),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: "Cuenta",
            categoryID: groceries.id,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.manual.rawValue,
            confidence: 1.0,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.corrected.rawValue,
            categorizationReason: "Corrected manually by the user.",
            fingerprint: "mercadona-train-1",
            isRecurringCandidate: false
        )

        let second = Transaction(
            bookingDate: .now,
            rawDescription: "COMPRA MERCADONA COLON",
            cleanedDescription: "MERCADONA COLON",
            merchantDisplayName: "Mercadona",
            merchantCanonicalName: "Mercadona",
            amount: Decimal(-31.20),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: "Cuenta",
            categoryID: groceries.id,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.manual.rawValue,
            confidence: 1.0,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.corrected.rawValue,
            categorizationReason: "Corrected manually by the user.",
            fingerprint: "mercadona-train-2",
            isRecurringCandidate: false
        )

        try container.transactionRepository.insert([first, second])
        try container.localModelManager.rebuildModel()

        let input = NormalizedTransactionDTO(
            externalID: nil,
            bookingDate: .now,
            valueDate: nil,
            rawDescription: "COMPRA TARJ MERCADONA CAMPANAR",
            cleanedDescription: "MERCADONA CAMPANAR",
            merchantDisplayName: "Mercadona",
            merchantCanonicalName: "Mercadona",
            amount: Decimal(-18.45),
            currencyCode: "EUR",
            accountName: "Cuenta",
            sign: -1,
            fingerprint: "mercadona-predict"
        )

        let decision = await container.categorizationOrchestrator.categorize(input)
        XCTAssertEqual(decision.categoryID, groceries.id)
        XCTAssertEqual(decision.source, .localML)
        XCTAssertGreaterThanOrEqual(decision.confidence, 0.55)
    }

    func testAppleAIActionMappingIncludesBudgetsSurface() {
        XCTAssertEqual(
            AppleAIIntent.actions(for: .budgets),
            [.budgetPressure, .categoriesOverPlan]
        )
        XCTAssertEqual(
            AppleAIIntent.actions(for: .dashboard),
            [.monthlyBriefing, .optimizeSpending]
        )
    }

    func testAppleAIFallbackHandlesEmptyData() async {
        let container = AppContainer(inMemory: true)
        let service = AppleAIGlobalActionService(availabilityService: UnavailableAIAvailabilityServiceStub())

        let result = await service.run(.monthlyBriefing, surface: .dashboard, using: container, language: .spanish)

        XCTAssertEqual(result.title, "Pulso del mes")
        XCTAssertFalse(result.summary.isEmpty)
        XCTAssertGreaterThanOrEqual(result.bullets.count, 3)
    }

    func testAppleAIFallbackUsesAccountingDateForMonthlyBriefing() async throws {
        let container = AppContainer(inMemory: true)
        let service = AppleAIGlobalActionService(availabilityService: UnavailableAIAvailabilityServiceStub())

        let payroll = Transaction(
            bookingDate: date(year: 2026, month: 1, day: 26),
            rawDescription: "NOMINA EMPRESA",
            cleanedDescription: "NOMINA EMPRESA",
            merchantDisplayName: "Empresa",
            merchantCanonicalName: "Empresa",
            amount: Decimal(1000),
            currencyCode: "EUR",
            kindRaw: TransactionKind.income.rawValue,
            accountName: "Cuenta",
            categoryID: nil,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.manual.rawValue,
            confidence: 1.0,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            categorizationReason: nil,
            fingerprint: "payroll-shift",
            isRecurringCandidate: false
        )
        let expense = Transaction(
            bookingDate: date(year: 2026, month: 2, day: 3),
            rawDescription: "ALQUILER FEBRERO",
            cleanedDescription: "ALQUILER FEBRERO",
            merchantDisplayName: "Casero",
            merchantCanonicalName: "Casero",
            amount: Decimal(-400),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: "Cuenta",
            categoryID: nil,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.manual.rawValue,
            confidence: 1.0,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            categorizationReason: nil,
            fingerprint: "expense-feb",
            isRecurringCandidate: false
        )

        try container.transactionRepository.insert([payroll, expense])

        let result = await service.run(.monthlyBriefing, surface: .dashboard, using: container, language: .spanish)
        let digitsOnly = result.summary.filter(\.isNumber)

        XCTAssertTrue(digitsOnly.contains("1000"))
        XCTAssertTrue(digitsOnly.contains("400"))
        XCTAssertTrue(digitsOnly.contains("600"))
    }

    func testAppleAIFallbackDetectsCategoryCleanupSignals() async throws {
        let container = AppContainer(inMemory: true)
        let service = AppleAIGlobalActionService(availabilityService: UnavailableAIAvailabilityServiceStub())

        try container.categoryRepository.ensureBaseCategories()
        let groceries = try XCTUnwrap(try container.categoryRepository.fetchAll().first(where: { $0.name == "Alimentacion" }))
        _ = try container.categoryRepository.fetchOrCreateBaseCategory(named: "Mascotas", isIncome: false)

        let context = ModelContext(container.modelContainer)
        context.insert(
            Category(
                name: "viajes",
                iconName: "airplane",
                colorHex: "#26A69A",
                isIncome: false,
                sortOrder: 999,
                isSystem: false
            )
        )
        try context.save()

        let transaction = Transaction(
            bookingDate: date(year: 2026, month: 4, day: 10),
            rawDescription: "MERCADONA RUZAFA",
            cleanedDescription: "MERCADONA RUZAFA",
            merchantDisplayName: "Mercadona",
            merchantCanonicalName: "Mercadona",
            amount: Decimal(-45),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: "Cuenta",
            categoryID: groceries.id,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.manual.rawValue,
            confidence: 1.0,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            categorizationReason: nil,
            fingerprint: "cleanup-1",
            isRecurringCandidate: false
        )
        try container.transactionRepository.insert(transaction)

        let result = await service.run(.categoryCleanup, surface: .categories, using: container, language: .spanish)
        let text = result.bullets.joined(separator: " ")

        XCTAssertEqual(result.title, "Limpieza de categorías")
        XCTAssertTrue(text.localizedCaseInsensitiveContains("Categorías sin uso") || text.localizedCaseInsensitiveContains("vacías"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("duplicadas") || text.localizedCaseInsensitiveContains("duplicados"))
    }

    func testAppleAIFallbackDetectsRecurringMerchantsAndRuleCandidates() async throws {
        let container = AppContainer(inMemory: true)
        let service = AppleAIGlobalActionService(availabilityService: UnavailableAIAvailabilityServiceStub())

        let first = Transaction(
            bookingDate: date(year: 2026, month: 4, day: 4),
            rawDescription: "NETFLIX ABRIL",
            cleanedDescription: "NETFLIX ABRIL",
            merchantDisplayName: "Netflix",
            merchantCanonicalName: "Netflix",
            amount: Decimal(-15.99),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: "Cuenta",
            categoryID: nil,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.unknown.rawValue,
            confidence: 0.22,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue,
            categorizationReason: nil,
            fingerprint: "netflix-1",
            isRecurringCandidate: false
        )
        let second = Transaction(
            bookingDate: date(year: 2026, month: 4, day: 11),
            rawDescription: "NETFLIX MAYO",
            cleanedDescription: "NETFLIX MAYO",
            merchantDisplayName: "Netflix",
            merchantCanonicalName: "Netflix",
            amount: Decimal(-15.99),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: "Cuenta",
            categoryID: nil,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.unknown.rawValue,
            confidence: 0.21,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue,
            categorizationReason: nil,
            fingerprint: "netflix-2",
            isRecurringCandidate: false
        )
        try container.transactionRepository.insert([first, second])

        let recurring = await service.run(.recurringMerchants, surface: .transactions, using: container, language: .spanish)
        let rules = await service.run(.ruleCandidates, surface: .categories, using: container, language: .spanish)

        XCTAssertTrue(recurring.bullets.joined(separator: " ").contains("Netflix"))
        XCTAssertTrue(rules.bullets.joined(separator: " ").contains("Netflix"))
    }

    func testAppleAIFallbackSummarizesBudgetPressure() async throws {
        let container = AppContainer(inMemory: true)
        let service = AppleAIGlobalActionService(availabilityService: UnavailableAIAvailabilityServiceStub())

        try container.categoryRepository.ensureBaseCategories()
        let groceries = try XCTUnwrap(try container.categoryRepository.fetchAll().first(where: { $0.name == "Alimentacion" }))
        try container.budgetRepository.save(
            Budget(categoryID: groceries.id, monthYear: currentMonthYearForTests(), limitAmount: Decimal(100))
        )

        let expense = Transaction(
            bookingDate: Date(),
            rawDescription: "MERCADONA ACTUAL",
            cleanedDescription: "MERCADONA ACTUAL",
            merchantDisplayName: "Mercadona",
            merchantCanonicalName: "Mercadona",
            amount: Decimal(-120),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            accountName: "Cuenta",
            categoryID: groceries.id,
            subcategoryID: nil,
            categorizationSourceRaw: CategorizationSource.manual.rawValue,
            confidence: 1.0,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            categorizationReason: nil,
            fingerprint: "budget-1",
            isRecurringCandidate: false
        )
        try container.transactionRepository.insert(expense)

        let result = await service.run(.budgetPressure, surface: .budgets, using: container, language: .spanish)

        XCTAssertEqual(result.title, "Presión de presupuestos")
        XCTAssertTrue(result.summary.contains("1 presupuestos activos") || result.summary.contains("1 presupuesto activo"))
        XCTAssertTrue(result.bullets.joined(separator: " ").localizedCaseInsensitiveContains("Alimentacion"))
    }

    func testAppleAIFallbackSummarizesImportHealth() async throws {
        let container = AppContainer(inMemory: true)
        let service = AppleAIGlobalActionService(availabilityService: UnavailableAIAvailabilityServiceStub())

        try container.importBatchRepository.saveBatch(
            fileName: "abril.csv",
            sourceType: "csv",
            rawRowCount: 20,
            validRowCount: 18,
            importedRowCount: 18,
            duplicatesSkipped: 2,
            pendingReviewCount: 5,
            fileFingerprint: "f1",
            rowFingerprint: "r1",
            dateRangeText: "01/04/2026 - 14/04/2026"
        )

        let result = await service.run(.importHealth, surface: .imports, using: container, language: .spanish)

        XCTAssertEqual(result.title, "Estado de importaciones")
        XCTAssertTrue(result.summary.contains("18"))
        XCTAssertTrue(result.bullets.joined(separator: " ").contains("abril.csv"))
    }

    func testAppleAIGlobalActionServiceRunsEndToEndWithSeededData() async throws {
        let container = AppContainer(inMemory: true)
        let service = AppleAIGlobalActionService(availabilityService: UnavailableAIAvailabilityServiceStub())

        try container.categoryRepository.ensureBaseCategories()
        let groceries = try XCTUnwrap(try container.categoryRepository.fetchAll().first(where: { $0.name == "Alimentacion" }))

        try container.transactionRepository.insert([
            Transaction(
                bookingDate: Date(),
                rawDescription: "MERCADONA 1",
                cleanedDescription: "MERCADONA 1",
                merchantDisplayName: "Mercadona",
                merchantCanonicalName: "Mercadona",
                amount: Decimal(-35),
                currencyCode: "EUR",
                kindRaw: TransactionKind.expense.rawValue,
                accountName: "Cuenta",
                categoryID: groceries.id,
                subcategoryID: nil,
                categorizationSourceRaw: CategorizationSource.manual.rawValue,
                confidence: 1.0,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue,
                categorizationReason: nil,
                fingerprint: "e2e-1",
                isRecurringCandidate: false
            ),
            Transaction(
                bookingDate: Date(),
                rawDescription: "SPOTIFY",
                cleanedDescription: "SPOTIFY",
                merchantDisplayName: "Spotify",
                merchantCanonicalName: "Spotify",
                amount: Decimal(-9.99),
                currencyCode: "EUR",
                kindRaw: TransactionKind.expense.rawValue,
                accountName: "Cuenta",
                categoryID: nil,
                subcategoryID: nil,
                categorizationSourceRaw: CategorizationSource.unknown.rawValue,
                confidence: 0.25,
                needsReview: true,
                reviewStatusRaw: ReviewStatus.pending.rawValue,
                categorizationReason: nil,
                fingerprint: "e2e-2",
                isRecurringCandidate: false
            )
        ])
        try container.importBatchRepository.saveBatch(
            fileName: "seed.csv",
            sourceType: "csv",
            rawRowCount: 2,
            validRowCount: 2,
            importedRowCount: 2,
            duplicatesSkipped: 0,
            pendingReviewCount: 1,
            fileFingerprint: "f2",
            rowFingerprint: "r2",
            dateRangeText: nil
        )

        let result = await service.run(.learningReadiness, surface: .settings, using: container, language: .spanish)

        XCTAssertFalse(result.summary.isEmpty)
        XCTAssertGreaterThanOrEqual(result.bullets.count, 3)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? .now
    }

    private func currentMonthYearForTests(referenceDate: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: referenceDate)
    }

    private func unitTestFixtureURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(relativePath)
    }

    private func projectRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func localizationKeys(in url: URL) throws -> Set<String> {
        let text = try String(contentsOf: url, encoding: .utf8)
        let regex = try XCTUnwrap(NSRegularExpression(pattern: "^\\s*\"((?:\\\\.|[^\"])*)\"\\s*=", options: [.anchorsMatchLines]))
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        return Set(matches.compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[keyRange])
        })
    }
}
