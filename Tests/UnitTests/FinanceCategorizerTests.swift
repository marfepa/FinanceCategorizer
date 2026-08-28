import XCTest
import SwiftData
#if os(macOS)
@testable import FinanceCategorizerMac
#else
@testable import FinanceCategorizerIOS
#endif

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

    func testAppLockStateFollowsPrivacyPreferenceWithoutAuthentication() async {
        let viewModel = AppLockViewModel()

        viewModel.lockIfEnabled(false)
        XCTAssertFalse(viewModel.isLocked)

        viewModel.lockIfEnabled(true)
        XCTAssertTrue(viewModel.isLocked)

        await viewModel.configure(isEnabled: false, reason: "Test")
        XCTAssertFalse(viewModel.isLocked)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPersistenceSchemaHasAnExplicitVersionAndMigrationPlan() {
        XCTAssertEqual(FinanceSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(FinanceMigrationPlan.schemas.count, 1)
        XCTAssertTrue(FinanceMigrationPlan.stages.isEmpty)
    }

    func testModelContainerFactoryOpensHealthyPersistentStoreSuccessfully() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("FinanceCategorizerTest.store")
        let setup = ModelContainerFactory.make(inMemory: false, customStoreURL: storeURL)

        XCTAssertNil(setup.recoveryIssue)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testModelContainerFactoryCreatesBackupAndRecoverySetupOnStoreFailure() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("CorruptStore.store")
        let corruptData = "INVALID_SQLITE_DATABASE_HEADER".data(using: .utf8)!
        try corruptData.write(to: storeURL)

        let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")
        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        try corruptData.write(to: shmURL)
        try corruptData.write(to: walURL)

        let setup = ModelContainerFactory.make(inMemory: false, customStoreURL: storeURL)

        let issue = try XCTUnwrap(setup.recoveryIssue)
        XCTAssertEqual(issue.storeURL, storeURL)

        let backupDir = try XCTUnwrap(issue.backupDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupDir.path))

        let backedUpStore = backupDir.appendingPathComponent(storeURL.lastPathComponent)
        let backedUpShm = backupDir.appendingPathComponent(shmURL.lastPathComponent)
        let backedUpWal = backupDir.appendingPathComponent(walURL.lastPathComponent)

        XCTAssertTrue(FileManager.default.fileExists(atPath: backedUpStore.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backedUpShm.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backedUpWal.path))
    }

    func testDashboardSnapshotSurfacesMonthlyProgressAndCategoryGrowth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let currentMonth = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 10)))
        let previousMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: -1, to: currentMonth))
        let groceries = Category(
            name: "Groceries",
            iconName: "cart",
            colorHex: "#4CAF50"
        )

        let transactions = [
            Transaction(
                bookingDate: currentMonth,
                rawDescription: "SALARY",
                cleanedDescription: "SALARY",
                amount: Decimal(1_800),
                kindRaw: TransactionKind.income.rawValue,
                categorizationSourceRaw: CategorizationSource.manual.rawValue,
                confidence: 1,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue,
                fingerprint: "salary-current"
            ),
            Transaction(
                bookingDate: currentMonth.addingTimeInterval(86_400),
                rawDescription: "GROCERY CURRENT",
                cleanedDescription: "GROCERY CURRENT",
                amount: Decimal(-150),
                categoryID: groceries.id,
                categorizationSourceRaw: CategorizationSource.manual.rawValue,
                confidence: 1,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue,
                fingerprint: "groceries-current"
            ),
            Transaction(
                bookingDate: previousMonth,
                rawDescription: "SALARY",
                cleanedDescription: "SALARY",
                amount: Decimal(1_800),
                kindRaw: TransactionKind.income.rawValue,
                categorizationSourceRaw: CategorizationSource.manual.rawValue,
                confidence: 1,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue,
                fingerprint: "salary-previous"
            ),
            Transaction(
                bookingDate: previousMonth.addingTimeInterval(86_400),
                rawDescription: "GROCERY PREVIOUS",
                cleanedDescription: "GROCERY PREVIOUS",
                amount: Decimal(-100),
                categoryID: groceries.id,
                categorizationSourceRaw: CategorizationSource.manual.rawValue,
                confidence: 1,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue,
                fingerprint: "groceries-previous"
            )
        ]

        let snapshot = try XCTUnwrap(
            DashboardInsightService().buildSnapshot(
                transactions: transactions,
                categories: [groceries],
                recentImports: [],
                locale: Locale(identifier: "en")
            )
        )
        let groceriesItem = try XCTUnwrap(snapshot.categoryChanges.first(where: { $0.name == "Groceries" }))

        XCTAssertEqual(snapshot.monthlyCashflow.count, 2)
        XCTAssertEqual(snapshot.totalIncome, Decimal(1_800))
        XCTAssertEqual(snapshot.totalExpenses, Decimal(150))
        XCTAssertEqual(groceriesItem.deltaFromPreviousMonth, Decimal(50))
        XCTAssertEqual(groceriesItem.deltaPercentage, 0.5)
        XCTAssertEqual(snapshot.monthlyCashflow.last?.expense, Decimal(150))
    }

    func testLocalizedStringFilesHaveTheSameKeys() throws {
        let englishKeys = try localizationKeys(in: projectRootURL().appendingPathComponent("Resources/en.lproj/Localizable.strings"))
        let spanishKeys = try localizationKeys(in: projectRootURL().appendingPathComponent("Resources/es.lproj/Localizable.strings"))
        XCTAssertEqual(englishKeys, spanishKeys, "English and Spanish localization catalogs must contain the same keys")
    }

    func testAnonymizedExportRemovesConceptAndMerchant() {
        let transaction = Transaction(
            bookingDate: Date(timeIntervalSince1970: 1_700_000_000),
            rawDescription: "SECRET MEDICAL PAYMENT",
            cleanedDescription: "SECRET MEDICAL PAYMENT",
            merchantCanonicalName: "Private Clinic",
            amount: Decimal(-125),
            fingerprint: "export-private"
        )

        let csv = ExportService.generateCSV(
            from: [transaction],
            categories: [],
            locale: Locale(identifier: "en_US"),
            privacyMode: .anonymized
        )

        XCTAssertFalse(csv.contains("SECRET MEDICAL PAYMENT"))
        XCTAssertFalse(csv.contains("Private Clinic"))
        XCTAssertTrue(csv.contains("Movement 1"))
        XCTAssertTrue(csv.contains("-125"))
    }

    func testExportAuditKeepsOnlyMostRecentFiftyEntries() throws {
        let suiteName = "ExportAuditTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let service = ExportAuditService(defaults: defaults)

        for index in 0..<55 {
            service.record(
                privacyMode: index.isMultiple(of: 2) ? .anonymized : .full,
                transactionCount: index,
                at: Date(timeIntervalSince1970: Double(index))
            )
        }

        let entries = service.entries()
        XCTAssertEqual(entries.count, 50)
        XCTAssertEqual(entries.first?.transactionCount, 54)
        XCTAssertEqual(entries.last?.transactionCount, 5)

        service.clear()
        XCTAssertTrue(service.entries().isEmpty)
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

    func testMerchantExtractionSkipsWalletPrefixes() {
        XCTAssertEqual(
            MerchantExtractionService().extract(from: "APPLE PAY EN LIDL VALENCIA"),
            "LIDL VALENCIA"
        )
    }

    func testConfidenceScorerPreservesReviewRequestBelowAutoAcceptThreshold() {
        let decision = CategorizationDecision(
            categoryID: UUID(),
            subcategoryID: nil,
            source: .localML,
            confidence: 0.78,
            shouldQueueForReview: true,
            isRecurringCandidate: false,
            reason: "Heuristic"
        )

        XCTAssertTrue(ConfidenceScorer().finalize(decision).shouldQueueForReview)
    }

    func testConfidenceScoreThresholds() {
        XCTAssertTrue(ConfidenceScore(value: 0.95).shouldAutoAccept)
        XCTAssertTrue(ConfidenceScore(value: 0.81).shouldAutoAcceptButMarkSoft)
        XCTAssertTrue(ConfidenceScore(value: 0.40).shouldSendToReview)
    }

    func testCategoryDirectionPolicyRejectsExpenseCategoryForIncome() {
        let original = CategorizationDecision(
            categoryID: UUID(),
            subcategoryID: nil,
            source: .merchantMemory,
            confidence: 0.98,
            shouldQueueForReview: false,
            isRecurringCandidate: false,
            reason: "Learned merchant"
        )

        let result = CategoryDirectionPolicy().rejectingIncompatible(
            original,
            categoryIsIncome: false,
            transactionKind: .income
        )

        XCTAssertNil(result.categoryID)
        XCTAssertTrue(result.shouldQueueForReview)
        XCTAssertEqual(result.source, .merchantMemory)
    }

    func testCategoryDirectionPolicyAllowsMatchingDirections() {
        let policy = CategoryDirectionPolicy()
        XCTAssertTrue(policy.isCompatible(categoryIsIncome: true, transactionKind: .income))
        XCTAssertTrue(policy.isCompatible(categoryIsIncome: false, transactionKind: .expense))
        XCTAssertFalse(policy.isCompatible(categoryIsIncome: false, transactionKind: .income))
        XCTAssertFalse(policy.isCompatible(categoryIsIncome: true, transactionKind: .expense))
    }

    func testImportCommitPersistsTransactionsAndBatchTogether() throws {
        let container = AppContainer(inMemory: true)
        let batchID = UUID()
        let transaction = Transaction(
            importBatchID: batchID,
            bookingDate: .now,
            rawDescription: "TEST IMPORT",
            cleanedDescription: "TEST IMPORT",
            amount: Decimal(-12),
            fingerprint: "atomic-import-test"
        )

        try container.importBatchRepository.commitImport(
            transactions: [transaction],
            id: batchID,
            fileName: "test.csv",
            sourceType: "csv",
            rawRowCount: 1,
            validRowCount: 1,
            importedRowCount: 1,
            duplicatesSkipped: 0,
            pendingReviewCount: 1,
            fileFingerprint: "file-test",
            rowFingerprint: "row-test",
            dateRangeText: nil
        )

        XCTAssertEqual(try container.transactionRepository.count(), 1)
        XCTAssertEqual(try container.importBatchRepository.fetchRecentBatches(limit: 1).first?.id, batchID)
    }

    func testTransactionRepositoryFetchesStablePagesNewestFirst() throws {
        let container = AppContainer(inMemory: true)
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let transactions = (0..<205).map { index in
            Transaction(
                bookingDate: baseDate.addingTimeInterval(Double(index)),
                rawDescription: "PAGE \(index)",
                cleanedDescription: "PAGE \(index)",
                amount: Decimal(-index - 1),
                fingerprint: "page-\(index)"
            )
        }
        try container.transactionRepository.insert(transactions)

        let firstPage = try container.transactionRepository.fetchPage(offset: 0, limit: 200)
        let secondPage = try container.transactionRepository.fetchPage(offset: 200, limit: 200)

        XCTAssertEqual(firstPage.count, 200)
        XCTAssertEqual(secondPage.count, 5)
        XCTAssertEqual(firstPage.first?.rawDescription, "PAGE 204")
        XCTAssertEqual(secondPage.last?.rawDescription, "PAGE 0")
        XCTAssertTrue(Set(firstPage.map(\.id)).isDisjoint(with: secondPage.map(\.id)))
    }

    func testAccountsViewModelCreatesLiabilityAndCalculatesNetWorth() throws {
        let container = AppContainer(inMemory: true)
        try container.accountRepository.save(Account(
            name: "Savings",
            currentBalance: Decimal(5_000),
            balanceAsOf: .now,
            balanceSourceRaw: BalanceSource.manual.rawValue
        ))
        let viewModel = AccountsViewModel()
        viewModel.name = "Credit card"
        viewModel.institution = "Test Bank"
        viewModel.currencyCode = "eur"
        viewModel.balanceText = "1200,50"
        viewModel.isLiability = true

        viewModel.save(using: container, language: .spanish)

        XCTAssertEqual(viewModel.accounts.count, 2)
        XCTAssertEqual(viewModel.netWorth, Decimal(string: "3799.50"))
        let liability = try XCTUnwrap(viewModel.accounts.first(where: { $0.name == "Credit card" }))
        XCTAssertTrue(liability.isLiability)
        XCTAssertEqual(liability.currencyCode, "EUR")
        XCTAssertEqual(liability.balance, Decimal(string: "1200.50"))
    }

    func testImportAssociatesTransactionsAndBalanceWithAccount() async throws {
        let container = AppContainer(inMemory: true)
        var reportedProgress: [Double] = []
        let csv = """
        Fecha;Concepto;Importe;Saldo
        01/08/2026;COMPRA TEST;-25,00;975,00
        """

        let summary = try await container.importOrchestrator.importCSV(
            csv,
            sourceFileName: "account-test.csv",
            language: .spanish,
            accountName: "Cuenta principal",
            progress: { reportedProgress.append($0) }
        )

        XCTAssertEqual(reportedProgress.last, 1.0)
        XCTAssertEqual(reportedProgress, reportedProgress.sorted())
        XCTAssertTrue(reportedProgress.allSatisfy { (0...1).contains($0) })
        XCTAssertEqual(summary.detectedAccounts, 1)
        XCTAssertEqual(try container.transactionRepository.fetchAll().first?.accountName, "Cuenta principal")
        let account = try XCTUnwrap(try container.accountRepository.fetchAll().first)
        XCTAssertEqual(account.name, "Cuenta principal")
        XCTAssertEqual(account.currentBalance, Decimal(975))
    }

    func testHeuristicsRecognizeMerchantsObservedInNumbersFiles() throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let model = LocalModelManager(
            transactionRepository: container.transactionRepository,
            storageDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("finance-categorizer-test-\(UUID().uuidString)")
        )
        let classifier = StatisticalClassifier(
            categoryRepository: container.categoryRepository,
            localModelManager: model
        )

        let cases: [(description: String, category: String)] = [
            ("MERCADONA MISLATA", "Alimentacion"),
            ("BARBERIA JAVI ALGEMESI", "Cuidado personal"),
            ("DECATHLON CARCAIXENT", "Deportes"),
            ("APPLE BILL ITUNES", "Suscripciones"),
            ("PARROQUIA SAN PIO X ALGEMESI", "Donaciones")
        ]

        for testCase in cases {
            let input = NormalizedTransactionDTO(
                externalID: nil,
                bookingDate: .now,
                valueDate: nil,
                rawDescription: testCase.description,
                cleanedDescription: testCase.description,
                merchantDisplayName: nil,
                merchantCanonicalName: nil,
                amount: Decimal(-20),
                currencyCode: "EUR",
                accountName: nil,
                sign: -1,
                fingerprint: UUID().uuidString
            )

            let decision = try XCTUnwrap(classifier.predict(input))
            let category = try XCTUnwrap(try container.categoryRepository.fetch(categoryID: try XCTUnwrap(decision.categoryID)))
            XCTAssertEqual(category.name, testCase.category, "Unexpected category for \(testCase.description)")
            XCTAssertGreaterThanOrEqual(decision.confidence, AppConfig.suggestionThreshold)
        }
    }

    func testRecategorizationStoresSuggestionWithoutOverwritingCurrentCategory() async throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let currentCategory = try XCTUnwrap(
            try container.categoryRepository.fetchAll().first(where: { $0.name == "Compras" })
        )
        let suggestedCategory = try XCTUnwrap(
            try container.categoryRepository.fetchAll().first(where: { $0.name == "Deportes" })
        )
        let transaction = Transaction(
            bookingDate: .now,
            rawDescription: "DECATHLON CARCAIXENT",
            cleanedDescription: "DECATHLON CARCAIXENT",
            merchantDisplayName: "Decathlon",
            merchantCanonicalName: "Decathlon",
            amount: Decimal(-65),
            categoryID: currentCategory.id,
            categorizationSourceRaw: CategorizationSource.localML.rawValue,
            confidence: 0.78,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            fingerprint: "decathlon-audit"
        )
        try container.transactionRepository.insert(transaction)

        let result = try await container.recategorizationService.analyze([transaction])
        let saved = try XCTUnwrap(try container.transactionRepository.fetch(transactionID: transaction.id))

        XCTAssertEqual(result.suggestionsCreated, 1)
        XCTAssertEqual(saved.categoryID, currentCategory.id)
        XCTAssertEqual(saved.suggestedCategoryID, suggestedCategory.id)
        XCTAssertTrue(try container.transactionRepository.fetchPendingReview().contains(where: { $0.id == transaction.id }))
    }

    func testRecategorizationSuggestionCanBeAcceptedAsManualCorrection() async throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let currentCategory = try XCTUnwrap(
            try container.categoryRepository.fetchAll().first(where: { $0.name == "Compras" })
        )
        let suggestedCategory = try XCTUnwrap(
            try container.categoryRepository.fetchAll().first(where: { $0.name == "Deportes" })
        )
        let transaction = Transaction(
            bookingDate: .now,
            rawDescription: "DECATHLON CARCAIXENT",
            cleanedDescription: "DECATHLON CARCAIXENT",
            merchantDisplayName: "Decathlon",
            merchantCanonicalName: "Decathlon",
            amount: Decimal(-65),
            categoryID: currentCategory.id,
            categorizationSourceRaw: CategorizationSource.localML.rawValue,
            confidence: 0.78,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            fingerprint: "decathlon-accept"
        )
        try container.transactionRepository.insert(transaction)
        _ = try await container.recategorizationService.analyze([transaction])

        let viewModel = ReviewQueueViewModel()
        viewModel.load(using: container)
        viewModel.select(try XCTUnwrap(viewModel.transactions.first))
        viewModel.acceptSuggestedCategory(using: container)

        let saved = try XCTUnwrap(try container.transactionRepository.fetch(transactionID: transaction.id))
        XCTAssertEqual(saved.categoryID, suggestedCategory.id)
        XCTAssertNil(saved.suggestedCategoryID)
        XCTAssertEqual(saved.categorizationSourceRaw, CategorizationSource.manual.rawValue)
        XCTAssertFalse(saved.needsReview)
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

    func testImportSkipsCrossBankMovementWithDifferentDescriptionAndAdjacentDate() async throws {
        let container = AppContainer(inMemory: true)

        let firstBankCSV = """
        Fecha;F. valor;Concepto;Importe;Saldo
        02/01/2026;02/01/2026;COMPRA TARJETA MERCADONA VALENCIA;-42,60;100,00
        """

        let firstSummary = try await container.importOrchestrator.importCSV(
            firstBankCSV,
            sourceFileName: "bank-a.csv",
            language: .spanish
        )

        XCTAssertEqual(firstSummary.importedCount, 1)

        let secondBankCSV = """
        Fecha;F. valor;Concepto;Importe;Saldo
        03/01/2026;03/01/2026;MERCADONA SUPERMERCADO;-42,60;57,40
        03/01/2026;03/01/2026;SPOTIFY PREMIUM;-9,99;47,41
        """

        let secondSummary = try await container.importOrchestrator.importCSV(
            secondBankCSV,
            sourceFileName: "bank-b.csv",
            language: .spanish
        )

        XCTAssertEqual(secondSummary.importedCount, 1)
        XCTAssertEqual(secondSummary.duplicatesSkipped, 1)
        XCTAssertEqual(try container.transactionRepository.count(), 2)
    }

    func testDuplicateAuditFindsAndPersistsCrossSourceGroup() throws {
        let container = AppContainer(inMemory: true)
        let calendar = Calendar(identifier: .gregorian)
        let firstDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        let secondDate = calendar.date(byAdding: .day, value: 1, to: firstDate)!

        let first = Transaction(
            importBatchID: UUID(),
            externalID: "bank-a-1",
            bookingDate: firstDate,
            valueDate: firstDate,
            rawDescription: "COMPRA TARJETA MERCADONA VALENCIA",
            cleanedDescription: "MERCADONA VALENCIA",
            merchantDisplayName: "Mercadona",
            merchantCanonicalName: "Mercadona",
            amount: Decimal(-42.60),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            fingerprint: "fingerprint-bank-a"
        )
        let second = Transaction(
            importBatchID: UUID(),
            bookingDate: secondDate,
            valueDate: secondDate,
            rawDescription: "MERCADONA SUPERMERCADO",
            cleanedDescription: "MERCADONA SUPERMERCADO",
            merchantDisplayName: "Mercadona",
            merchantCanonicalName: "Mercadona",
            amount: Decimal(-42.60),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            fingerprint: "fingerprint-bank-b"
        )

        try container.transactionRepository.insert([first, second])

        let groups = container.duplicateAuditService.analyze(
            transactions: try container.transactionRepository.fetchAll()
        )

        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(group.transactionIDs), Set([first.id, second.id]))
        XCTAssertEqual(group.reasonKey, "duplicate.reason.crossSource")
        XCTAssertEqual(group.recommendedKeepID, first.id)

        try container.transactionRepository.applyDuplicateAudit(groups)
        var persisted = try container.transactionRepository.fetchAll()
        XCTAssertTrue(persisted.allSatisfy { $0.duplicateGroupID == group.id })
        XCTAssertTrue(persisted.allSatisfy { $0.duplicateReviewStatusRaw == DuplicateReviewStatus.pending.rawValue })

        try container.transactionRepository.dismissDuplicateGroup(groupID: group.id)
        persisted = try container.transactionRepository.fetchAll()
        XCTAssertTrue(persisted.allSatisfy { $0.duplicateReviewStatusRaw == DuplicateReviewStatus.dismissed.rawValue })

        // Re-scanning the same data must not undo the user's dismissal.
        try container.transactionRepository.applyDuplicateAudit(
            container.duplicateAuditService.analyze(transactions: persisted)
        )
        persisted = try container.transactionRepository.fetchAll()
        XCTAssertTrue(persisted.allSatisfy { $0.duplicateReviewStatusRaw == DuplicateReviewStatus.dismissed.rawValue })

        try container.transactionRepository.deleteDuplicateGroup(groupID: group.id, keeping: first.id)
        XCTAssertEqual(try container.transactionRepository.count(), 1)
        let kept = try XCTUnwrap(try container.transactionRepository.fetch(transactionID: first.id))
        XCTAssertNil(kept.duplicateGroupID)
        XCTAssertNil(kept.duplicateReviewStatusRaw)
    }

    func testDuplicateAuditIgnoresLegitimateRowsFromSameImportBatch() throws {
        let container = AppContainer(inMemory: true)
        let importBatchID = UUID()
        let date = Date(timeIntervalSince1970: 1_767_312_000)

        let first = Transaction(
            importBatchID: importBatchID,
            bookingDate: date,
            valueDate: date,
            rawDescription: "CAFETERIA TEST",
            cleanedDescription: "CAFETERIA TEST",
            merchantCanonicalName: "Cafeteria Test",
            amount: Decimal(-2.50),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            fingerprint: "same-fingerprint"
        )
        let second = Transaction(
            importBatchID: importBatchID,
            bookingDate: date,
            valueDate: date,
            rawDescription: "CAFETERIA TEST",
            cleanedDescription: "CAFETERIA TEST",
            merchantCanonicalName: "Cafeteria Test",
            amount: Decimal(-2.50),
            currencyCode: "EUR",
            kindRaw: TransactionKind.expense.rawValue,
            fingerprint: "same-fingerprint"
        )

        try container.transactionRepository.insert([first, second])

        let groups = container.duplicateAuditService.analyze(
            transactions: try container.transactionRepository.fetchAll()
        )

        XCTAssertTrue(groups.isEmpty)
    }

    func testDuplicateRepositoryCanResolveAllSuggestedGroups() throws {
        let container = AppContainer(inMemory: true)
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!

        let transactions = [
            Transaction(
                importBatchID: UUID(),
                externalID: "mercadona-a",
                bookingDate: date,
                valueDate: date,
                rawDescription: "COMPRA MERCADONA VALENCIA",
                cleanedDescription: "MERCADONA VALENCIA",
                merchantCanonicalName: "Mercadona",
                amount: Decimal(-12.50),
                currencyCode: "EUR",
                kindRaw: TransactionKind.expense.rawValue,
                fingerprint: "mercadona-a"
            ),
            Transaction(
                importBatchID: UUID(),
                bookingDate: date,
                valueDate: date,
                rawDescription: "MERCADONA SUPERMERCADO",
                cleanedDescription: "MERCADONA SUPERMERCADO",
                merchantCanonicalName: "Mercadona",
                amount: Decimal(-12.50),
                currencyCode: "EUR",
                kindRaw: TransactionKind.expense.rawValue,
                fingerprint: "mercadona-b"
            ),
            Transaction(
                importBatchID: UUID(),
                externalID: "spotify-a",
                bookingDate: date,
                valueDate: date,
                rawDescription: "PAGO SPOTIFY PREMIUM",
                cleanedDescription: "SPOTIFY PREMIUM",
                merchantCanonicalName: "Spotify",
                amount: Decimal(-8.99),
                currencyCode: "EUR",
                kindRaw: TransactionKind.expense.rawValue,
                fingerprint: "spotify-a"
            ),
            Transaction(
                importBatchID: UUID(),
                bookingDate: date,
                valueDate: date,
                rawDescription: "SPOTIFY SUSCRIPCION",
                cleanedDescription: "SPOTIFY SUSCRIPCION",
                merchantCanonicalName: "Spotify",
                amount: Decimal(-8.99),
                currencyCode: "EUR",
                kindRaw: TransactionKind.expense.rawValue,
                fingerprint: "spotify-b"
            )
        ]

        try container.transactionRepository.insert(transactions)
        let groups = container.duplicateAuditService.analyze(
            transactions: try container.transactionRepository.fetchAll()
        )
        XCTAssertEqual(groups.count, 2)

        try container.transactionRepository.applyDuplicateAudit(groups)
        let deletedCount = try container.transactionRepository.resolveDuplicateGroups(groups)

        XCTAssertEqual(deletedCount, 2)
        XCTAssertEqual(try container.transactionRepository.count(), 2)
        XCTAssertTrue(try container.transactionRepository.fetchAll().allSatisfy {
            $0.duplicateGroupID == nil && $0.duplicateReviewStatusRaw == nil
        })
    }

    func testDuplicateDetectorDoesNotMatchOppositeDirections() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        let normalizer = TransactionNormalizer()

        let expense = normalizer.normalize(
            ParsedRowDTO(
                externalID: nil,
                bookingDate: date,
                valueDate: nil,
                description: "MERCADONA VALENCIA",
                amount: Decimal(-42.60),
                currencyCode: "EUR",
                accountName: nil
            )
        )
        let income = normalizer.normalize(
            ParsedRowDTO(
                externalID: nil,
                bookingDate: date,
                valueDate: nil,
                description: "MERCADONA DEVOLUCION",
                amount: Decimal(42.60),
                currencyCode: "EUR",
                accountName: nil
            )
        )

        let matches = DuplicateMovementDetector().findMatches(
            for: [DuplicateMovementCandidate(normalized: income)],
            against: [DuplicateMovementCandidate(normalized: expense)]
        )

        XCTAssertTrue(matches.isEmpty)
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

    func testOpenbankPDFParserHandlesSeparatedColumnsAndMultilineConcepts() throws {
        let openbankText = """
        Openbank
        Fecha Operación Fecha Valor Concepto Importe Saldo
        01/02/2026 01/02/2026 TRANSFERENCIA DE GENERALITAT VALENCIANA,
        335,39 EUR 751,37 EUR
        CONCEPTO NOMINA EDUCACION C.PRIVADOS 01-2026
        02/02/2026 02/02/2026 Apple pay: COMPRA EN LIDL ALGEMESI,
        -6,45 EUR 744,92 EUR
        TARJETA : 5154520019563402 EL 2026-02-02
        Página: 1 / 1
        """

        let preview = try PDFParsingService().preview(text: openbankText)

        XCTAssertEqual(preview.rows.count, 2)
        XCTAssertTrue(preview.invalidRows.isEmpty)
        XCTAssertFalse(preview.requiresManualMapping)
        XCTAssertEqual(preview.rows.first?.amount, Decimal(string: "335.39"))
        XCTAssertEqual(preview.rows.last?.amount, Decimal(string: "-6.45"))
        XCTAssertTrue(preview.rows.last?.concept.contains("LIDL ALGEMESI") == true)
    }

    func testRedactedOpenbankPDFIsBlockedInsteadOfImportingPartialRows() throws {
        let redactedText = """
        OpenBank, S.A.
        Fecha Operación Fecha Valor Concepto Importe Saldo
        Apple pay: COMPRA EN LIDL ALGEMESI EL 2026-02-02
        Página: 1 / 1
        """

        let preview = try PDFParsingService().preview(text: redactedText)

        XCTAssertTrue(preview.rows.isEmpty)
        XCTAssertTrue(preview.requiresManualMapping)
        XCTAssertEqual(preview.diagnostics.importableRowCount, 0)
        XCTAssertEqual(preview.invalidRows.first?.severity, .error)
    }

    func testTransactionKindResolverRecognizesOpenbankMovementSemantics() {
        let resolver = TransactionKindResolver()

        XCTAssertEqual(
            resolver.resolve(rawDescription: "RECARGA TARJETA PREPAGO", cleanedDescription: "RECARGA TARJETA PREPAGO", amount: -41.47),
            .transfer
        )
        XCTAssertEqual(
            resolver.resolve(rawDescription: "TRANSFERENCIA DE FERNANDEZ PARDO MARIO", cleanedDescription: "TRANSFERENCIA DE FERNANDEZ PARDO MARIO", amount: 500),
            .transfer
        )
        XCTAssertEqual(
            resolver.resolve(rawDescription: "BIZUM DE MARIA C M", cleanedDescription: "BIZUM DE MARIA C M", amount: 18.70),
            .income
        )
        XCTAssertEqual(
            resolver.resolve(rawDescription: "BIZUM A FAVOR DE MARIA C M", cleanedDescription: "BIZUM A FAVOR DE MARIA C M", amount: -10),
            .expense
        )
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

    func testCategoryAuditCanAssignAlternativeCategory() throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let categories = try container.categoryRepository.fetchAll()
        let currentCategory = try XCTUnwrap(categories.first(where: { $0.name == "Alimentacion" }))
        let suggestedCategory = try XCTUnwrap(categories.first(where: { $0.name == "Compras" }))
        let alternativeCategory = try XCTUnwrap(categories.first(where: { $0.name == "Salud" }))
        let transaction = Transaction(
            bookingDate: .now,
            rawDescription: "BIZUM DE INES",
            cleanedDescription: "BIZUM DE INES",
            amount: Decimal(-13.70),
            categoryID: currentCategory.id,
            categorizationSourceRaw: CategorizationSource.localML.rawValue,
            confidence: 0.67,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue,
            fingerprint: "audit-alternative-category"
        )
        try container.transactionRepository.insert(transaction)
        try container.transactionRepository.saveRecategorizationSuggestion(
            transactionID: transaction.id,
            categoryID: suggestedCategory.id,
            source: .localML,
            confidence: 0.67,
            reason: "The proposal is intentionally wrong for this test."
        )

        let viewModel = CategoryAuditViewModel()
        viewModel.load(using: container)
        let selected = try XCTUnwrap(viewModel.transactions.first(where: { $0.id == transaction.id }))
        viewModel.assignCategory(alternativeCategory.id, to: selected, using: container)

        let saved = try XCTUnwrap(try container.transactionRepository.fetch(transactionID: transaction.id))
        XCTAssertEqual(saved.categoryID, alternativeCategory.id)
        XCTAssertNil(saved.suggestedCategoryID)
        XCTAssertEqual(saved.categorizationSourceRaw, CategorizationSource.manual.rawValue)
        XCTAssertFalse(saved.needsReview)
    }

    func testCascadingRecategorizationAndFutureLearning() async throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let categories = try container.categoryRepository.fetchAll()
        let oldCategory = try XCTUnwrap(categories.first(where: { $0.name == "Alimentacion" }))
        let newCategory = try XCTUnwrap(categories.first(where: { $0.name == "Ocio" }))

        let tx1 = Transaction(
            bookingDate: .now,
            rawDescription: "NETFLIX ENTERTAINMENT",
            cleanedDescription: "NETFLIX ENTERTAINMENT",
            merchantDisplayName: "Netflix",
            merchantCanonicalName: "Netflix",
            amount: Decimal(-15.99),
            categoryID: oldCategory.id,
            categorizationSourceRaw: CategorizationSource.rule.rawValue,
            confidence: 0.8,
            fingerprint: "netflix-1"
        )
        let tx2 = Transaction(
            bookingDate: .now.addingTimeInterval(-86400),
            rawDescription: "NETFLIX ENTERTAINMENT",
            cleanedDescription: "NETFLIX ENTERTAINMENT",
            merchantDisplayName: "Netflix",
            merchantCanonicalName: "Netflix",
            amount: Decimal(-15.99),
            categoryID: oldCategory.id,
            categorizationSourceRaw: CategorizationSource.rule.rawValue,
            confidence: 0.8,
            fingerprint: "netflix-2"
        )
        let tx3 = Transaction(
            bookingDate: .now.addingTimeInterval(-172800),
            rawDescription: "NETFLIX ENTERTAINMENT",
            cleanedDescription: "NETFLIX ENTERTAINMENT",
            merchantDisplayName: "Netflix",
            merchantCanonicalName: "Netflix",
            amount: Decimal(-15.99),
            categoryID: nil,
            categorizationSourceRaw: CategorizationSource.unknown.rawValue,
            confidence: 0.0,
            fingerprint: "netflix-3"
        )

        try container.transactionRepository.insert(tx1)
        try container.transactionRepository.insert(tx2)
        try container.transactionRepository.insert(tx3)

        let count = try container.correctionLearningService.applyCorrection(
            for: tx1,
            categoryID: newCategory.id,
            applyToFuture: true
        )

        XCTAssertEqual(count, 3)

        let savedTx1 = try XCTUnwrap(container.transactionRepository.fetch(transactionID: tx1.id))
        let savedTx2 = try XCTUnwrap(container.transactionRepository.fetch(transactionID: tx2.id))
        let savedTx3 = try XCTUnwrap(container.transactionRepository.fetch(transactionID: tx3.id))

        XCTAssertEqual(savedTx1.categoryID, newCategory.id)
        XCTAssertEqual(savedTx2.categoryID, newCategory.id)
        XCTAssertEqual(savedTx3.categoryID, newCategory.id)

        let futureDTO = NormalizedTransactionDTO(
            externalID: nil,
            bookingDate: .now,
            valueDate: nil,
            rawDescription: "NETFLIX ENTERTAINMENT",
            cleanedDescription: "NETFLIX ENTERTAINMENT",
            merchantDisplayName: "Netflix",
            merchantCanonicalName: "Netflix",
            amount: Decimal(-15.99),
            currencyCode: "EUR",
            accountName: nil,
            sign: -1,
            fingerprint: "netflix-future"
        )

        let decision = await container.categorizationOrchestrator.categorize(futureDTO)
        XCTAssertEqual(decision.categoryID, newCategory.id)
        XCTAssertGreaterThanOrEqual(decision.confidence, 0.9)
    }

    func testInternalTransferRecategorizationDoesNotTouchRentOrGenericMovements() async throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let categories = try container.categoryRepository.fetchAll()
        let transfersCategory = try XCTUnwrap(categories.first(where: { $0.name == "Transferencias" }))
        let housingCategory = try XCTUnwrap(categories.first(where: { $0.name == "Hogar" }))
        let leisureCategory = try XCTUnwrap(categories.first(where: { $0.name == "Ocio" }))

        let internalTx = Transaction(
            bookingDate: .now,
            rawDescription: "TRANSFERENCIA SEPA TRASPASO CUENTA PROPIA",
            cleanedDescription: "TRANSFERENCIA SEPA TRASPASO CUENTA PROPIA",
            amount: Decimal(-200.00),
            kindRaw: TransactionKind.transfer.rawValue,
            categoryID: transfersCategory.id,
            fingerprint: "internal-1"
        )

        let rentTx = Transaction(
            bookingDate: .now,
            rawDescription: "TRANSFERENCIA SEPA ALQUILER SEPTIEMBRE",
            cleanedDescription: "TRANSFERENCIA SEPA ALQUILER SEPTIEMBRE",
            amount: Decimal(-850.00),
            kindRaw: TransactionKind.expense.rawValue,
            categoryID: housingCategory.id,
            fingerprint: "rent-1"
        )

        try container.transactionRepository.insert(internalTx)
        try container.transactionRepository.insert(rentTx)

        let count = try container.correctionLearningService.applyCorrection(
            for: internalTx,
            categoryID: leisureCategory.id,
            applyToFuture: true
        )

        XCTAssertEqual(count, 1)

        let savedInternal = try XCTUnwrap(container.transactionRepository.fetch(transactionID: internalTx.id))
        let savedRent = try XCTUnwrap(container.transactionRepository.fetch(transactionID: rentTx.id))

        XCTAssertEqual(savedInternal.categoryID, leisureCategory.id)
        XCTAssertEqual(savedRent.categoryID, housingCategory.id)

        let rentDTO = NormalizedTransactionDTO(
            externalID: nil,
            bookingDate: .now,
            valueDate: nil,
            rawDescription: "TRANSFERENCIA SEPA ALQUILER OCTUBRE",
            cleanedDescription: "TRANSFERENCIA SEPA ALQUILER OCTUBRE",
            merchantDisplayName: nil,
            merchantCanonicalName: nil,
            amount: Decimal(-850.00),
            currencyCode: "EUR",
            accountName: nil,
            sign: -1,
            fingerprint: "rent-future",
            kind: .expense
        )

        let decision = await container.categorizationOrchestrator.categorize(rentDTO)
        XCTAssertNotEqual(decision.categoryID, leisureCategory.id)
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
            merchantCanonicalName: nil,
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
            merchantCanonicalName: nil,
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
            merchantCanonicalName: nil,
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

    func testAppleAIFallbackUsesBudgetAllocationForMonthlyBriefing() async throws {
        let container = AppContainer(inMemory: true)
        let service = AppleAIGlobalActionService(availabilityService: UnavailableAIAvailabilityServiceStub())

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        let payroll = Transaction(
            bookingDate: date(year: currentYear, month: currentMonth, day: 10),
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
            bookingDate: date(year: currentYear, month: currentMonth, day: 11),
            rawDescription: "ALQUILER ENERO",
            cleanedDescription: "ALQUILER ENERO",
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
            fingerprint: "expense-jan",
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

    func testCajamarCSVFixtureBuildsPreviewAndImports() throws {
        let url = unitTestFixtureURL("cajamar/cajamar_basic.csv")
        let csv = try String(contentsOf: url, encoding: .utf8)

        let preview = try CSVParsingService().preview(text: csv)

        XCTAssertEqual(preview.diagnostics.rawRowCount, 4)
        XCTAssertEqual(preview.rows.count, 3)
        XCTAssertNotNil(preview.mapping)
        XCTAssertFalse(preview.requiresManualMapping)

        let firstRow = try XCTUnwrap(preview.rows.first)
        XCTAssertEqual(firstRow.amount, Decimal(string: "-42.60"))
        XCTAssertEqual(firstRow.concept, "COMPRA TARJ MERCADONA TEST")
    }

    func testAbancaCSVFixtureBuildsPreviewAndImports() throws {
        let url = unitTestFixtureURL("abanca/abanca_basic.csv")
        let csv = try String(contentsOf: url, encoding: .utf8)

        let preview = try CSVParsingService().preview(text: csv)

        XCTAssertEqual(preview.diagnostics.rawRowCount, 4)
        XCTAssertEqual(preview.rows.count, 3)
        XCTAssertNotNil(preview.mapping)
        XCTAssertFalse(preview.requiresManualMapping)

        let firstRow = try XCTUnwrap(preview.rows.first)
        XCTAssertEqual(firstRow.amount, Decimal(string: "-42.60"))
        XCTAssertEqual(firstRow.concept, "COMPRA TARJ MERCADONA TEST")
    }

    func testSingleRowCSVDoesNotRequireManualMapping() throws {
        let csv = """
        Date,Description,Amount
        2026-01-02,Single movement,-12.50
        """

        let preview = try CSVParsingService().preview(text: csv)

        XCTAssertEqual(preview.rows.count, 1)
        XCTAssertFalse(preview.requiresManualMapping)
    }

    func testDashboardExcludesTransfersFromCashflow() {
        let date = Date()
        let categoryID = UUID()
        let income = Transaction(
            bookingDate: date,
            rawDescription: "Salary",
            cleanedDescription: "Salary",
            amount: 100,
            kindRaw: TransactionKind.income.rawValue,
            categoryID: categoryID,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let expense = Transaction(
            bookingDate: date,
            rawDescription: "Groceries",
            cleanedDescription: "Groceries",
            amount: -40,
            kindRaw: TransactionKind.expense.rawValue,
            categoryID: categoryID,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let transfer = Transaction(
            bookingDate: date,
            rawDescription: "Internal transfer",
            cleanedDescription: "Internal transfer",
            amount: 500,
            kindRaw: TransactionKind.transfer.rawValue,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue
        )

        let snapshot = DashboardInsightService().buildSnapshot(
            transactions: [income, expense, transfer],
            categories: [],
            recentImports: [],
            locale: .current
        )

        XCTAssertEqual(snapshot?.totalIncome, Decimal(100))
        XCTAssertEqual(snapshot?.totalExpenses, Decimal(40))
        XCTAssertEqual(snapshot?.netBalance, Decimal(60))
        XCTAssertEqual(snapshot?.pendingReviewCount, 0)
    }

    func testDashboardAttributesLatePayrollToBudgetMonth() {
        let payroll = Transaction(
            bookingDate: date(year: 2026, month: 7, day: 30),
            rawDescription: "NOMINA JULIO",
            cleanedDescription: "NOMINA JULIO",
            amount: Decimal(2_000),
            kindRaw: TransactionKind.income.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let expense = Transaction(
            bookingDate: date(year: 2026, month: 7, day: 31),
            rawDescription: "MERCADONA",
            cleanedDescription: "MERCADONA",
            amount: Decimal(-75),
            kindRaw: TransactionKind.expense.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )

        let snapshot = DashboardInsightService().buildSnapshot(
            transactions: [payroll, expense],
            categories: [],
            recentImports: [],
            locale: .current,
            now: date(year: 2026, month: 8, day: 4)
        )

        XCTAssertEqual(snapshot?.totalIncome, Decimal(2_000))
        XCTAssertEqual(snapshot?.totalExpenses, Decimal.zero)
        XCTAssertEqual(snapshot?.netBalance, Decimal(2_000))
        XCTAssertTrue(snapshot?.monthTitle.lowercased().contains(currentMonthName(for: date(year: 2026, month: 8, day: 1))) == true)
    }

    func testPayrollAccountingDateMatchesBookingDate() {
        for month in [7, 8, 9] {
            let payroll = Transaction(
                bookingDate: date(year: 2026, month: month, day: 30),
                rawDescription: "NOMINA",
                cleanedDescription: "NOMINA",
                amount: Decimal(2_000),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            )

            let accountingComponents = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: payroll.accountingDate
            )
            XCTAssertEqual(accountingComponents.year, 2026)
            XCTAssertEqual(accountingComponents.month, month)
            XCTAssertEqual(accountingComponents.day, 30)
        }
    }

    func testJunePayrollRowsWithoutExtraLabelAreIncludedInJune() {
        let transactions = [
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 29),
                rawDescription: "TRANSFERENCIA DE EMPRESA, CONCEPTO NOMINA JUNIO",
                cleanedDescription: "TRANSFERENCIA DE EMPRESA CONCEPTO NOMINA JUNIO",
                amount: Decimal(1_500),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 29),
                rawDescription: "NOMINA NOMINAS EMPRESA",
                cleanedDescription: "NOMINA NOMINAS EMPRESA",
                amount: Decimal(4_200),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 29),
                rawDescription: "NOMINA NOMINAS EMPRESA",
                cleanedDescription: "NOMINA NOMINAS EMPRESA",
                amount: Decimal(2_800),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 29),
                rawDescription: "NOMINA NOMINAS EMPRESA",
                cleanedDescription: "NOMINA NOMINAS EMPRESA",
                amount: Decimal(380),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            )
        ]
        let snapshot = FinancialAnalysisService().analyze(
            transactions: transactions,
            categories: [],
            range: .all,
            now: date(year: 2026, month: 8, day: 4)
        )

        XCTAssertEqual(snapshot.totalIncome, Decimal(8_880))
        XCTAssertEqual(snapshot.monthlyCashflow.first?.income, Decimal(8_880))
    }

    func testBudgetPayrollAllocationKeepsJuneExtraAndMovesJulyOrdinaryPayroll() {
        let payrollAmounts: [(Int, Decimal)] = [
            (3, 4_800),
            (4, 4_900),
            (5, 5_000),
            (6, 9_000),
            (7, 4_800)
        ]
        let transactions = payrollAmounts.map { month, amount in
            Transaction(
                bookingDate: date(year: 2026, month: month, day: 29),
                rawDescription: "NOMINA GENERALITAT",
                cleanedDescription: "NOMINA GENERALITAT",
                amount: amount,
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            )
        }
        let scope = FinancialReportingScope(
            now: date(year: 2026, month: 8, day: 4),
            dateBasis: .budget,
            payrollCutoffDay: 25
        )
        let entries = scope.eligibleEntries(
            from: transactions,
            classifier: FinancialMovementClassifier()
        )
        let calendar = Calendar.current
        let incomeInMonth: (Int) -> Decimal = { month in
            entries
                .filter { calendar.component(.month, from: $0.date) == month }
                .reduce(Decimal.zero) { $0 + $1.amount }
        }

        XCTAssertEqual(incomeInMonth(6), Decimal(9_100))
        XCTAssertEqual(incomeInMonth(7), Decimal(4_900))
        XCTAssertEqual(incomeInMonth(8), Decimal(4_800))
        XCTAssertEqual(entries.reduce(Decimal.zero) { $0 + $1.amount }, Decimal(28_500))
    }

    func testDashboardExcludesInternalMovementCategoryEvenWhenStoredAsIncomeOrExpense() {
        let internalCategory = Category(
            name: "Movimiento interno",
            iconName: "arrow.left.arrow.right",
            colorHex: "#607D8B",
            isIncome: false
        )
        let externalIncome = Transaction(
            bookingDate: date(year: 2026, month: 8, day: 3),
            rawDescription: "DEVOLUCION",
            cleanedDescription: "DEVOLUCION",
            amount: 50,
            kindRaw: TransactionKind.income.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let internalIncome = Transaction(
            bookingDate: date(year: 2026, month: 8, day: 3),
            rawDescription: "MARIO FERNANDEZ PARDO",
            cleanedDescription: "MARIO FERNANDEZ PARDO",
            amount: 1_000,
            kindRaw: TransactionKind.income.rawValue,
            categoryID: internalCategory.id,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let internalExpense = Transaction(
            bookingDate: date(year: 2026, month: 8, day: 3),
            rawDescription: "TRASPASO",
            cleanedDescription: "TRASPASO",
            amount: -1_050,
            kindRaw: TransactionKind.expense.rawValue,
            categoryID: internalCategory.id,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let snapshot = DashboardInsightService().buildSnapshot(
            transactions: [externalIncome, internalIncome, internalExpense],
            categories: [internalCategory],
            recentImports: [],
            locale: .current,
            now: date(year: 2026, month: 8, day: 4)
        )

        XCTAssertEqual(snapshot?.totalIncome, Decimal(50))
        XCTAssertEqual(snapshot?.totalExpenses, Decimal.zero)
        XCTAssertEqual(snapshot?.netBalance, Decimal(50))
        XCTAssertEqual(snapshot?.dataQuality.internalTransferCount, 2)
    }

    func testDashboardDoesNotUseFutureOrTransferToSelectReferenceMonth() {
        let payroll = Transaction(
            bookingDate: date(year: 2026, month: 7, day: 30),
            rawDescription: "NOMINA JULIO",
            cleanedDescription: "NOMINA JULIO",
            amount: Decimal(2_000),
            kindRaw: TransactionKind.income.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let transfer = Transaction(
            bookingDate: date(year: 2026, month: 8, day: 2),
            rawDescription: "TRASPASO ENTRE CUENTAS",
            cleanedDescription: "TRASPASO ENTRE CUENTAS",
            amount: Decimal(-2_000),
            kindRaw: TransactionKind.transfer.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let futureExpense = Transaction(
            bookingDate: date(year: 2026, month: 12, day: 30),
            rawDescription: "COMPRA FUTURA",
            cleanedDescription: "COMPRA FUTURA",
            amount: Decimal(-10),
            kindRaw: TransactionKind.expense.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )

        let snapshot = DashboardInsightService().buildSnapshot(
            transactions: [payroll, transfer, futureExpense],
            categories: [],
            recentImports: [],
            locale: .current,
            now: date(year: 2026, month: 8, day: 4)
        )

        XCTAssertEqual(snapshot?.totalIncome, Decimal(2_000))
        XCTAssertEqual(snapshot?.totalExpenses, Decimal.zero)
        XCTAssertTrue(snapshot?.monthTitle.lowercased().contains(currentMonthName(for: date(year: 2026, month: 8, day: 1))) == true)
    }

    func testDashboardShowsLegacySupermarketSpendAsFoodAndReportsItForReview() {
        let groceries = Category(
            name: "Alimentacion",
            iconName: "cart",
            colorHex: "#4CAF50",
            isIncome: false
        )
        let legacySupermarketExpense = Transaction(
            bookingDate: date(year: 2026, month: 7, day: 30),
            rawDescription: "APPLE PAY EN LIDL",
            cleanedDescription: "APPLE PAY EN LIDL",
            merchantCanonicalName: "Apple Pay En",
            amount: Decimal(-18),
            kindRaw: TransactionKind.expense.rawValue,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue
        )

        let snapshot = DashboardInsightService().buildSnapshot(
            transactions: [legacySupermarketExpense],
            categories: [groceries],
            recentImports: [],
            locale: .current,
            now: date(year: 2026, month: 8, day: 4)
        )

        XCTAssertEqual(snapshot?.topCategories.first?.name, "Alimentacion")
        XCTAssertEqual(snapshot?.topCategories.first?.amount, Decimal(18))
        XCTAssertEqual(snapshot?.uncategorizedExpenseCount, 1)
        XCTAssertEqual(snapshot?.uncategorizedExpenseAmount, Decimal(18))
    }

    func testDashboardReportsNetTrendAndExpenseCoverage() {
        let groceries = Category(
            name: "Alimentacion",
            iconName: "cart",
            colorHex: "#4CAF50",
            isIncome: false
        )
        let juneIncome = Transaction(
            bookingDate: date(year: 2026, month: 6, day: 5),
            rawDescription: "NOMINA JUNIO",
            cleanedDescription: "NOMINA JUNIO",
            amount: 100,
            kindRaw: TransactionKind.income.rawValue,
            categoryID: groceries.id,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let juneExpense = Transaction(
            bookingDate: date(year: 2026, month: 6, day: 6),
            rawDescription: "LIDL",
            cleanedDescription: "LIDL",
            amount: -40,
            kindRaw: TransactionKind.expense.rawValue,
            categoryID: groceries.id,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let julyIncome = Transaction(
            bookingDate: date(year: 2026, month: 7, day: 5),
            rawDescription: "NOMINA JULIO",
            cleanedDescription: "NOMINA JULIO",
            amount: 100,
            kindRaw: TransactionKind.income.rawValue,
            categoryID: groceries.id,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let julyExpense = Transaction(
            bookingDate: date(year: 2026, month: 7, day: 6),
            rawDescription: "LIDL",
            cleanedDescription: "LIDL",
            amount: -80,
            kindRaw: TransactionKind.expense.rawValue,
            categoryID: groceries.id,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let internalTransfer = Transaction(
            bookingDate: date(year: 2026, month: 7, day: 7),
            rawDescription: "TRASPASO ENTRE CUENTAS",
            cleanedDescription: "TRASPASO ENTRE CUENTAS",
            amount: 500,
            kindRaw: TransactionKind.transfer.rawValue,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue
        )

        let snapshot = DashboardInsightService().buildSnapshot(
            transactions: [juneIncome, juneExpense, julyIncome, julyExpense, internalTransfer],
            categories: [groceries],
            recentImports: [],
            locale: .current,
            now: date(year: 2026, month: 8, day: 4)
        )

        XCTAssertEqual(snapshot?.netBalance, Decimal(20))
        XCTAssertEqual(snapshot?.netTrend, .decreasing)
        XCTAssertEqual(snapshot?.netDeltaFromPreviousMonth, Decimal(-40))
        XCTAssertEqual(snapshot?.dataQuality.expenseCategorizationCoverage, 1)
        XCTAssertEqual(snapshot?.dataQuality.internalTransferCount, 1)
        XCTAssertTrue(snapshot?.dataQuality.isReliable == true)
    }

    func testFinancialAnalysisDetectsCategorySpikesAcrossMonths() {
        let groceries = Category(
            name: "Alimentacion",
            iconName: "cart",
            colorHex: "#4CAF50",
            isIncome: false
        )
        let shopping = Category(
            name: "Compras",
            iconName: "bag",
            colorHex: "#FF9800",
            isIncome: false
        )
        let transactions = [
            Transaction(bookingDate: date(year: 2026, month: 1, day: 5), rawDescription: "LIDL", cleanedDescription: "LIDL", amount: -100, kindRaw: TransactionKind.expense.rawValue, categoryID: groceries.id, needsReview: false, reviewStatusRaw: ReviewStatus.accepted.rawValue),
            Transaction(bookingDate: date(year: 2026, month: 2, day: 5), rawDescription: "LIDL", cleanedDescription: "LIDL", amount: -110, kindRaw: TransactionKind.expense.rawValue, categoryID: groceries.id, needsReview: false, reviewStatusRaw: ReviewStatus.accepted.rawValue),
            Transaction(bookingDate: date(year: 2026, month: 3, day: 5), rawDescription: "LIDL", cleanedDescription: "LIDL", amount: -180, kindRaw: TransactionKind.expense.rawValue, categoryID: groceries.id, needsReview: false, reviewStatusRaw: ReviewStatus.accepted.rawValue),
            Transaction(bookingDate: date(year: 2026, month: 3, day: 6), rawDescription: "MANGO", cleanedDescription: "MANGO", amount: -50, kindRaw: TransactionKind.expense.rawValue, categoryID: shopping.id, needsReview: false, reviewStatusRaw: ReviewStatus.accepted.rawValue)
        ]

        let snapshot = FinancialAnalysisService().analyze(
            transactions: transactions,
            categories: [groceries, shopping],
            range: .all
        )

        let groceriesEvolution = snapshot.categoryEvolution.first(where: { $0.categoryName == "Alimentacion" })
        let shoppingEvolution = snapshot.categoryEvolution.first(where: { $0.categoryName == "Compras" })

        XCTAssertEqual(snapshot.netBalance, Decimal(-440))
        XCTAssertEqual(snapshot.netTrend, .decreasing)
        XCTAssertEqual(groceriesEvolution?.latestAmount, Decimal(180))
        XCTAssertEqual(groceriesEvolution?.previousAmount, Decimal(110))
        XCTAssertTrue(groceriesEvolution?.isSpiking == true)
        XCTAssertTrue(shoppingEvolution?.isSpiking == true)
        XCTAssertEqual(snapshot.dataQuality.expenseCategorizationCoverage, 1)
    }

    func testDashboardAndAnalysisUseTheSameCurrentAccountingMonth() throws {
        let groceries = Category(
            name: "Alimentacion",
            iconName: "cart",
            colorHex: "#4CAF50",
            isIncome: false
        )
        let now = date(year: 2026, month: 8, day: 4)
        let transactions = [
            Transaction(
                bookingDate: date(year: 2026, month: 8, day: 1),
                rawDescription: "NOMINA AGOSTO",
                cleanedDescription: "NOMINA AGOSTO",
                amount: Decimal(string: "5834.21")!,
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 8, day: 2),
                rawDescription: "MERCADONA",
                cleanedDescription: "MERCADONA",
                amount: Decimal(string: "-1707.21")!,
                kindRaw: TransactionKind.expense.rawValue,
                categoryID: groceries.id,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 9, day: 1),
                rawDescription: "FUTURE MOVEMENT",
                cleanedDescription: "FUTURE MOVEMENT",
                amount: Decimal(string: "-660.15")!,
                kindRaw: TransactionKind.expense.rawValue,
                categoryID: groceries.id,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            )
        ]

        let dashboard = try XCTUnwrap(
            DashboardInsightService().buildSnapshot(
                transactions: transactions,
                categories: [groceries],
                recentImports: [],
                locale: Locale(identifier: "es"),
                now: now
            )
        )
        let analysis = FinancialAnalysisService().analyze(
            transactions: transactions,
            categories: [groceries],
            range: .month,
            now: now
        )

        XCTAssertEqual(dashboard.totalIncome, analysis.totalIncome)
        XCTAssertEqual(dashboard.totalExpenses, analysis.totalExpenses)
        XCTAssertEqual(dashboard.netBalance, analysis.netBalance)
        XCTAssertEqual(analysis.totalIncome, Decimal(string: "5834.21")!)
        XCTAssertEqual(analysis.totalExpenses, Decimal(string: "1707.21")!)
        XCTAssertFalse(analysis.monthlyCashflow.contains { $0.monthLabel.lowercased().contains("sep") })
    }

    func testSupermarketSignalsOverrideGenericMerchantMemory() async throws {
        let container = AppContainer(inMemory: true)
        let categories = try container.categoryRepository.fetchAll()
        let groceries = try XCTUnwrap(categories.first(where: { $0.name == "Alimentacion" }))
        let shopping = try XCTUnwrap(categories.first(where: { $0.name == "Compras" }))

        let previous = Transaction(
            bookingDate: date(year: 2026, month: 6, day: 1),
            rawDescription: "CARREFOUR",
            cleanedDescription: "CARREFOUR",
            merchantCanonicalName: "Carrefour",
            amount: Decimal(-20),
            kindRaw: TransactionKind.expense.rawValue,
            categoryID: shopping.id,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        try container.transactionRepository.insert(previous)

        let decision = await container.categorizationOrchestrator.categorize(
            NormalizedTransactionDTO(
                externalID: nil,
                bookingDate: date(year: 2026, month: 7, day: 30),
                valueDate: nil,
                rawDescription: "CARREFOUR EXPRESS",
                cleanedDescription: "CARREFOUR EXPRESS",
                merchantDisplayName: "Carrefour",
                merchantCanonicalName: "Carrefour",
                amount: Decimal(-18),
                currencyCode: "EUR",
                accountName: nil,
                sign: -1,
                fingerprint: "carrefour-test"
            )
        )

        XCTAssertEqual(decision.categoryID, groceries.id)
    }

    func testTransferIsRemovedFromReviewQueue() throws {
        let container = AppContainer(inMemory: true)
        let transfer = Transaction(
            bookingDate: .now,
            rawDescription: "Internal transfer",
            cleanedDescription: "Internal transfer",
            amount: -500,
            kindRaw: TransactionKind.transfer.rawValue,
            needsReview: true,
            reviewStatusRaw: ReviewStatus.pending.rawValue
        )

        try container.transactionRepository.insert(transfer)

        XCTAssertTrue(try container.transactionRepository.fetchPendingReview().isEmpty)
    }

    func testRuleUpdatePersistsChangedFields() throws {
        let container = AppContainer(inMemory: true)
        try container.categoryRepository.ensureBaseCategories()
        let category = try XCTUnwrap(try container.categoryRepository.fetchAll().first)

        try container.ruleRepository.createRule(
            name: "Original",
            merchantContains: "merchant",
            targetCategoryID: category.id,
            createdFromUserCorrection: false
        )
        let rule = try XCTUnwrap(try container.ruleRepository.fetchAll().first)
        rule.name = "Updated"
        rule.amountMin = Decimal(12.50)

        try container.ruleRepository.update(rule)

        let saved = try XCTUnwrap(try container.ruleRepository.fetchAll().first)
        XCTAssertEqual(saved.name, "Updated")
        XCTAssertEqual(saved.amountMin, Decimal(12.50))
    }

    func testBudgetRepositoryRejectsInvalidAndDuplicateBudgets() throws {
        let container = AppContainer(inMemory: true)
        let categoryID = UUID()
        let monthYear = "2026-08"

        XCTAssertThrowsError(try container.budgetRepository.save(
            Budget(categoryID: categoryID, monthYear: monthYear, limitAmount: .zero)
        ))

        try container.budgetRepository.save(
            Budget(categoryID: categoryID, monthYear: monthYear, limitAmount: Decimal(100))
        )

        XCTAssertThrowsError(try container.budgetRepository.save(
            Budget(categoryID: categoryID, monthYear: monthYear, limitAmount: Decimal(200))
        ))
    }

    func testAISettingsPersistFeatureFlags() {
        let originalAI = FeatureFlags.aiSuggestionsEnabled
        let originalFoundationModels = FeatureFlags.foundationModelsEnabled
        defer {
            FeatureFlags.aiSuggestionsEnabled = originalAI
            FeatureFlags.foundationModelsEnabled = originalFoundationModels
        }

        let viewModel = SettingsViewModel()
        viewModel.aiEnabled = !originalAI
        viewModel.foundationModelsEnabled = !originalFoundationModels

        XCTAssertEqual(FeatureFlags.aiSuggestionsEnabled, !originalAI)
        XCTAssertEqual(FeatureFlags.foundationModelsEnabled, !originalFoundationModels)
    }

    func testFinancialPlanningUsesImportedBalanceAndKeepsGoalsAsAllocation() {
        let transaction = Transaction(
            bookingDate: date(year: 2026, month: 8, day: 4),
            rawDescription: "COMPRA",
            cleanedDescription: "COMPRA",
            amount: Decimal(-10),
            balanceAfter: Decimal(1_990),
            kindRaw: TransactionKind.expense.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let account = Account(name: "Cuenta principal")
        let goal = SavingsGoal(
            name: "Emergencia",
            kind: .emergency,
            targetAmount: Decimal(5_000),
            allocatedAmount: Decimal(500),
            monthlyContribution: Decimal(250),
            targetDate: date(year: 2027, month: 8, day: 5)
        )

        let snapshot = FinancialPlanningService().buildSnapshot(
            transactions: [transaction],
            accounts: [account],
            goals: [goal],
            now: date(year: 2026, month: 8, day: 5)
        )

        XCTAssertEqual(snapshot.totalBalance, Decimal(1_990))
        XCTAssertEqual(snapshot.allocatedToGoals, Decimal(500))
        XCTAssertEqual(snapshot.availableBalance, Decimal(1_490))
        XCTAssertTrue(snapshot.isBalanceConfirmed)
        XCTAssertEqual(snapshot.goals.first?.projectedAmount, Decimal(3_500))
    }

    func testFinancialPlanningFallsBackToEstimatedImportedFlowWhenNoBalanceExists() {
        let income = Transaction(
            bookingDate: date(year: 2026, month: 8, day: 1),
            rawDescription: "NOMINA",
            cleanedDescription: "NOMINA",
            amount: Decimal(2_000),
            kindRaw: TransactionKind.income.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )
        let expense = Transaction(
            bookingDate: date(year: 2026, month: 8, day: 2),
            rawDescription: "COMPRA",
            cleanedDescription: "COMPRA",
            amount: Decimal(-300),
            kindRaw: TransactionKind.expense.rawValue,
            needsReview: false,
            reviewStatusRaw: ReviewStatus.accepted.rawValue
        )

        let snapshot = FinancialPlanningService().buildSnapshot(
            transactions: [income, expense],
            accounts: [],
            goals: [],
            now: date(year: 2026, month: 8, day: 5)
        )

        XCTAssertEqual(snapshot.totalBalance, Decimal(1_700))
        XCTAssertFalse(snapshot.isBalanceConfirmed)
        XCTAssertEqual(snapshot.positions.first?.source, .estimated)
    }

    func testFinancialPlanningProjectsConfirmedBalanceFromAverageMonthlySaving() {
        let transactions = [
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 1),
                rawDescription: "NOMINA",
                cleanedDescription: "NOMINA",
                amount: Decimal(1_000),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 2),
                rawDescription: "COMPRA",
                cleanedDescription: "COMPRA",
                amount: Decimal(-600),
                kindRaw: TransactionKind.expense.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 15),
                rawDescription: "PAGA EXTRA",
                cleanedDescription: "PAGA EXTRA",
                amount: Decimal(10_000),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 7, day: 1),
                rawDescription: "NOMINA",
                cleanedDescription: "NOMINA",
                amount: Decimal(1_000),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 7, day: 2),
                rawDescription: "COMPRA",
                cleanedDescription: "COMPRA",
                amount: Decimal(-600),
                kindRaw: TransactionKind.expense.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 8, day: 1),
                rawDescription: "NOMINA",
                cleanedDescription: "NOMINA",
                amount: Decimal(1_000),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 8, day: 2),
                rawDescription: "COMPRA",
                cleanedDescription: "COMPRA",
                amount: Decimal(-600),
                balanceAfter: Decimal(10_000),
                kindRaw: TransactionKind.expense.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            )
        ]
        let goal = SavingsGoal(
            name: "Emergencia",
            kind: .emergency,
            targetAmount: Decimal(5_000),
            allocatedAmount: Decimal(500),
            monthlyContribution: Decimal(100)
        )

        let snapshot = FinancialPlanningService().buildSnapshot(
            transactions: transactions,
            accounts: [],
            goals: [goal],
            now: date(year: 2026, month: 8, day: 5)
        )

        XCTAssertEqual(snapshot.totalBalance, Decimal(10_000))
        XCTAssertEqual(snapshot.recurringMonthlyIncome, Decimal(1_000))
        XCTAssertEqual(snapshot.recurringMonthlyExpenses, Decimal(600))
        XCTAssertEqual(snapshot.monthlySavingsAverage, Decimal(400))
        XCTAssertGreaterThan(snapshot.historicalMonthlySavingsAverage, snapshot.monthlySavingsAverage)
        XCTAssertEqual(snapshot.projectedBalance12Months, Decimal(14_800))
        XCTAssertEqual(snapshot.projectedAvailableBalance12Months, Decimal(13_100))
        XCTAssertEqual(snapshot.balanceProjection.count, 13)
        XCTAssertEqual(snapshot.balanceProjection.first?.balance, Decimal(10_000))
        XCTAssertEqual(snapshot.balanceProjection.last?.balance, Decimal(14_800))
        XCTAssertEqual(snapshot.balanceProjection.first?.isProjected, false)
        XCTAssertEqual(snapshot.balanceProjection.last?.isProjected, true)
    }

    func testFinancialPlanningExcludesLoansAndGenericTransfersFromRecurringIncome() {
        var transactions: [Transaction] = []
        for month in 3...8 {
            transactions.append(
                Transaction(
                    bookingDate: date(year: 2026, month: month, day: 1),
                    rawDescription: "NOMINA EMPRESA",
                    cleanedDescription: "NOMINA EMPRESA",
                    amount: Decimal(2_000),
                    kindRaw: TransactionKind.income.rawValue,
                    needsReview: false,
                    reviewStatusRaw: ReviewStatus.accepted.rawValue
                )
            )
            transactions.append(
                Transaction(
                    bookingDate: date(year: 2026, month: month, day: 2),
                    rawDescription: "ALQUILER VIVIENDA",
                    cleanedDescription: "ALQUILER VIVIENDA",
                    merchantCanonicalName: "Alquiler",
                    amount: Decimal(-800),
                    kindRaw: TransactionKind.expense.rawValue,
                    needsReview: false,
                    reviewStatusRaw: ReviewStatus.accepted.rawValue
                )
            )
        }

        transactions.append(contentsOf: [
            Transaction(
                bookingDate: date(year: 2026, month: 4, day: 10),
                rawDescription: "DISPOSICION PRESTAMO",
                cleanedDescription: "DISPOSICION PRESTAMO",
                amount: Decimal(24_000),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 10),
                rawDescription: "TRANSFERENCIA RECIBIDA PRESTAMO",
                cleanedDescription: "TRANSFERENCIA RECIBIDA PRESTAMO",
                amount: Decimal(20_000),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 7, day: 10),
                rawDescription: "TRANSF INMEDIATA RECIBIDA",
                cleanedDescription: "TRANSF INMEDIATA RECIBIDA",
                amount: Decimal(20_000),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 8, day: 10),
                rawDescription: "TRANSF INMEDIATA RECIBIDA",
                cleanedDescription: "TRANSF INMEDIATA RECIBIDA",
                amount: Decimal(10),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 15),
                rawDescription: "S/ORD.TRANSFERENCIA OBRA",
                cleanedDescription: "S/ORD.TRANSFERENCIA OBRA",
                amount: Decimal(-7_000),
                kindRaw: TransactionKind.expense.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            )
        ])

        let snapshot = FinancialPlanningService().buildSnapshot(
            transactions: transactions,
            accounts: [],
            goals: [],
            now: date(year: 2026, month: 8, day: 15)
        )

        XCTAssertEqual(snapshot.recurringMonthlyIncome, Decimal(2_000))
        XCTAssertEqual(snapshot.recurringMonthlyExpenses, Decimal(800))
        XCTAssertEqual(snapshot.monthlySavingsAverage, Decimal(1_200))
    }

    func testFinancialPlanningIgnoresPendingDuplicateAndKeepsExtraSalaryOutOfBaseline() {
        var transactions: [Transaction] = []
        for month in 3...8 {
            transactions.append(
                Transaction(
                    bookingDate: date(year: 2026, month: month, day: 1),
                    rawDescription: "NOMINA",
                    cleanedDescription: "NOMINA",
                    amount: Decimal(1_500),
                    kindRaw: TransactionKind.income.rawValue,
                    needsReview: false,
                    reviewStatusRaw: ReviewStatus.accepted.rawValue
                )
            )
            transactions.append(
                Transaction(
                    bookingDate: date(year: 2026, month: month, day: 2),
                    rawDescription: "GASTOS CASA",
                    cleanedDescription: "GASTOS CASA",
                    amount: Decimal(-500),
                    kindRaw: TransactionKind.expense.rawValue,
                    needsReview: false,
                    reviewStatusRaw: ReviewStatus.accepted.rawValue
                )
            )
        }

        transactions.append(contentsOf: [
            Transaction(
                bookingDate: date(year: 2026, month: 8, day: 3),
                rawDescription: "PAGA EXTRA",
                cleanedDescription: "PAGA EXTRA",
                amount: Decimal(12_000),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue
            ),
            Transaction(
                bookingDate: date(year: 2026, month: 6, day: 1),
                rawDescription: "NOMINA",
                cleanedDescription: "NOMINA",
                amount: Decimal(1_500),
                kindRaw: TransactionKind.income.rawValue,
                needsReview: false,
                reviewStatusRaw: ReviewStatus.accepted.rawValue,
                duplicateGroupID: "duplicate-salary",
                duplicateReviewStatusRaw: DuplicateReviewStatus.pending.rawValue
            )
        ])

        let snapshot = FinancialPlanningService().buildSnapshot(
            transactions: transactions,
            accounts: [],
            goals: [],
            now: date(year: 2026, month: 8, day: 15)
        )

        XCTAssertEqual(snapshot.recurringMonthlyIncome, Decimal(1_500))
        XCTAssertEqual(snapshot.recurringMonthlyExpenses, Decimal(500))
        XCTAssertEqual(snapshot.monthlySavingsAverage, Decimal(1_000))
    }

    func testFinancialPlanningUsesMedianOperatingIncomeWhenLabelsVary() {
        let incomeCategory = Category(
            name: "Ingresos",
            iconName: "arrow.down.circle",
            colorHex: "#2E7D32",
            isIncome: true
        )
        var transactions: [Transaction] = []
        let monthlyIncome: [Decimal] = [6_000, 16_000, 6_000]

        for (index, month) in (6...8).enumerated() {
            transactions.append(
                Transaction(
                    bookingDate: date(year: 2026, month: month, day: 1),
                    rawDescription: "TRANSFERENCIA EMPRESA \(month)",
                    cleanedDescription: "TRANSFERENCIA EMPRESA \(month)",
                    amount: monthlyIncome[index],
                    kindRaw: TransactionKind.income.rawValue,
                    categoryID: incomeCategory.id,
                    needsReview: false,
                    reviewStatusRaw: ReviewStatus.accepted.rawValue
                )
            )
        }

        let snapshot = FinancialPlanningService().buildSnapshot(
            transactions: transactions,
            accounts: [],
            goals: [],
            categories: [incomeCategory],
            now: date(year: 2026, month: 8, day: 15)
        )

        XCTAssertEqual(snapshot.recurringMonthlyIncome, Decimal(6_000))
    }

    func testFinancialPlanningTreatsNewHomePurchasesAsDecliningTemporaryExpenses() {
        let incomeCategory = Category(
            name: "Ingresos",
            iconName: "arrow.down.circle",
            colorHex: "#2E7D32",
            isIncome: true
        )
        let shoppingCategory = Category(
            name: "Compras",
            iconName: "bag",
            colorHex: "#7E57C2"
        )
        let homeCategory = Category(
            name: "Hogar",
            iconName: "house",
            colorHex: "#8D6E63"
        )
        var transactions: [Transaction] = []
        let homePurchaseAmounts: [Decimal] = [500, 4_000, 6_000, 3_000, 1_500, 500]

        for (index, month) in (3...8).enumerated() {
            transactions.append(
                Transaction(
                    bookingDate: date(year: 2026, month: month, day: 1),
                    rawDescription: "NOMINA EMPRESA",
                    cleanedDescription: "NOMINA EMPRESA",
                    amount: Decimal(3_000),
                    kindRaw: TransactionKind.income.rawValue,
                    categoryID: incomeCategory.id,
                    needsReview: false,
                    reviewStatusRaw: ReviewStatus.accepted.rawValue
                )
            )
            transactions.append(
                Transaction(
                    bookingDate: date(year: 2026, month: month, day: 2),
                    rawDescription: "ALQUILER VIVIENDA",
                    cleanedDescription: "ALQUILER VIVIENDA",
                    merchantCanonicalName: "Alquiler",
                    amount: Decimal(-1_000),
                    kindRaw: TransactionKind.expense.rawValue,
                    categoryID: homeCategory.id,
                    needsReview: false,
                    reviewStatusRaw: ReviewStatus.accepted.rawValue
                )
            )
            transactions.append(
                Transaction(
                    bookingDate: date(year: 2026, month: month, day: 3),
                    rawDescription: "MERCADONA",
                    cleanedDescription: "MERCADONA",
                    merchantCanonicalName: "Mercadona",
                    amount: Decimal(-300),
                    kindRaw: TransactionKind.expense.rawValue,
                    needsReview: false,
                    reviewStatusRaw: ReviewStatus.accepted.rawValue
                )
            )
            transactions.append(
                Transaction(
                    bookingDate: date(year: 2026, month: month, day: 4),
                    rawDescription: "AMAZON COMPRA CASA",
                    cleanedDescription: "AMAZON COMPRA CASA",
                    merchantCanonicalName: "Amazon",
                    amount: -homePurchaseAmounts[index],
                    kindRaw: TransactionKind.expense.rawValue,
                    categoryID: shoppingCategory.id,
                    needsReview: false,
                    reviewStatusRaw: ReviewStatus.accepted.rawValue
                )
            )
        }

        let snapshot = FinancialPlanningService().buildSnapshot(
            transactions: transactions,
            accounts: [],
            goals: [],
            categories: [incomeCategory, shoppingCategory, homeCategory],
            now: date(year: 2026, month: 8, day: 15)
        )

        XCTAssertEqual(snapshot.recurringMonthlyIncome, Decimal(3_000))
        XCTAssertEqual(snapshot.recurringMonthlyExpenses, Decimal(1_800))
        XCTAssertEqual(snapshot.monthlySavingsAverage, Decimal(1_200))
    }

    func testImportBalanceIsCarriedIntoNormalizedTransaction() {
        let parsed = ParsedRowDTO(
            externalID: nil,
            bookingDate: date(year: 2026, month: 8, day: 4),
            valueDate: nil,
            description: "COMPRA",
            amount: Decimal(-10),
            balance: Decimal(1_990),
            currencyCode: "EUR",
            accountName: nil
        )

        let normalized = TransactionNormalizer().normalize(parsed)

        XCTAssertEqual(normalized.balance, Decimal(1_990))
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? .now
    }

    private func currentMonthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date).lowercased()
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

    func testEuropeanThousandsAndDecimalNumberParsing() {
        // European thousands without comma (e.g., 1.250 EUR -> 1250)
        XCTAssertEqual(ImportValueParser.parseAmount("1.250"), Decimal(1250))
        XCTAssertEqual(ImportValueParser.parseAmount("50.000"), Decimal(50000))
        XCTAssertEqual(ImportValueParser.parseAmount("1.250.000"), Decimal(1250000))

        // European standard with comma decimal
        XCTAssertEqual(ImportValueParser.parseAmount("1.250,50"), Decimal(string: "1250.50"))
        XCTAssertEqual(ImportValueParser.parseAmount("1250,50"), Decimal(string: "1250.50"))
        XCTAssertEqual(ImportValueParser.parseAmount("12,50"), Decimal(string: "12.50"))

        // Negative European amounts
        XCTAssertEqual(ImportValueParser.parseAmount("-1.250,00"), Decimal(-1250))
        XCTAssertEqual(ImportValueParser.parseAmount("-50.000"), Decimal(-50000))

        // US standard with dot decimal
        XCTAssertEqual(ImportValueParser.parseAmount("12.50"), Decimal(string: "12.50"))
        XCTAssertEqual(ImportValueParser.parseAmount("1,250.50"), Decimal(string: "1250.50"))
    }

    func testMultiEncodingFileImportServiceReadsWindows1252AndUTF8() throws {
        let service = FileImportService()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testContent = "Fecha;Concepto;Importe\n01/08/2026;Nómina y transferencias;1.500,00 €\n"

        // Test UTF-8
        let utf8URL = tempDir.appendingPathComponent("test_utf8.csv")
        try testContent.data(using: .utf8)?.write(to: utf8URL)
        let utf8Read = try service.readText(from: utf8URL)
        XCTAssertTrue(utf8Read.contains("Nómina"))

        // Test Windows-1252
        let winURL = tempDir.appendingPathComponent("test_win1252.csv")
        try testContent.data(using: .windowsCP1252)?.write(to: winURL)
        let winRead = try service.readText(from: winURL)
        XCTAssertTrue(winRead.contains("Nómina"))
    }
}
