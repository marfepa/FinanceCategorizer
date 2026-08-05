import Foundation

enum LocalModelReadinessState: Equatable {
    case noModel
    case needsMoreExamples(missingExamples: Int, missingCategories: Int)
    case ready
}

struct LocalModelReadiness {
    let isReady: Bool
    let state: LocalModelReadinessState
    let learnedExampleCount: Int
    let readyCategoryCount: Int
    let totalCategoryCount: Int
    let lastUpdatedAt: Date?
}

@MainActor
final class LocalModelManager {
    private let transactionRepository: TransactionRepository
    private let trainer: CreateMLTrainer
    private let storageURL: URL

    private(set) var profile: LocalModelProfile?

    init(
        transactionRepository: TransactionRepository,
        trainer: CreateMLTrainer = CreateMLTrainer(),
        storageDirectory: URL? = nil
    ) {
        self.transactionRepository = transactionRepository
        self.trainer = trainer

        let baseDirectory = storageDirectory ?? Self.defaultStorageDirectory()
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        self.storageURL = baseDirectory.appendingPathComponent("local-categorization-profile.json")
        self.profile = Self.loadProfile(from: self.storageURL)
    }

    func reloadIfAvailable() {
        profile = Self.loadProfile(from: storageURL)
    }

    func rebuildModel() throws {
        let examples = try trainingExamples()
        profile = trainer.trainProfile(from: examples)
        try persistProfile()
    }

    func rebuildModelIfNeeded(minimumExamples: Int = AppConfig.minimumLocalModelExamplesToTrain) throws {
        let examples = try trainingExamples()
        guard examples.count >= minimumExamples else { return }
        profile = trainer.trainProfile(from: examples)
        try persistProfile()
    }

    func predict(_ input: NormalizedTransactionDTO) -> LocalModelPrediction? {
        guard let profile else { return nil }
        return trainer.predict(input: input, profile: profile)
    }

    func profileSummary() -> String {
        let language = AppLanguage.currentSelection
        guard let profile else { return language.localized("localModel.profileSummary.notTrained") }
        let sampleCount = profile.categories.reduce(0) { $0 + $1.sampleCount }
        return language.localized(
            "localModel.profileSummary.updated",
            language.format(date: profile.updatedAt, dateStyle: .medium, timeStyle: .short),
            language.formatInteger(sampleCount)
        )
    }

    func readinessStatus() throws -> LocalModelReadiness {
        let learnedExamples = try trainingExamples().count

        guard let profile else {
            return LocalModelReadiness(
                isReady: false,
                state: .noModel,
                learnedExampleCount: learnedExamples,
                readyCategoryCount: 0,
                totalCategoryCount: 0,
                lastUpdatedAt: nil
            )
        }

        let readyCategories = profile.categories.filter { $0.sampleCount >= AppConfig.minimumExamplesPerReadyCategory }.count
        let totalCategories = profile.categories.count
        let isReady = learnedExamples >= AppConfig.minimumLocalModelExamplesForReadyState &&
            readyCategories >= AppConfig.minimumReadyCategories

        let state: LocalModelReadinessState
        if isReady {
            state = .ready
        } else {
            let missingExamples = max(0, AppConfig.minimumLocalModelExamplesForReadyState - learnedExamples)
            let missingCategories = max(0, AppConfig.minimumReadyCategories - readyCategories)
            state = .needsMoreExamples(missingExamples: missingExamples, missingCategories: missingCategories)
        }

        return LocalModelReadiness(
            isReady: isReady,
            state: state,
            learnedExampleCount: learnedExamples,
            readyCategoryCount: readyCategories,
            totalCategoryCount: totalCategories,
            lastUpdatedAt: profile.updatedAt
        )
    }

    private func trainingExamples() throws -> [LocalTrainingExample] {
        try transactionRepository.fetchAll()
            .filter { !$0.needsReview && $0.categoryID != nil }
            .compactMap { transaction in
                guard transaction.categorizationSourceRaw == CategorizationSource.manual.rawValue ||
                        transaction.categorizationSourceRaw == CategorizationSource.rule.rawValue else {
                    return nil
                }
                guard let categoryID = transaction.categoryID else { return nil }
                return LocalTrainingExample(
                    categoryID: categoryID,
                    merchant: transaction.merchantCanonicalName,
                    description: transaction.cleanedDescription.isEmpty ? transaction.rawDescription : transaction.cleanedDescription,
                    sign: transaction.amount >= 0 ? 1 : -1,
                    amount: transaction.amount,
                    isRecurring: transaction.isRecurringCandidate
                )
            }
    }

    private func persistProfile() throws {
        guard let profile else {
            try? FileManager.default.removeItem(at: storageURL)
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        try data.write(to: storageURL, options: .atomic)
    }

    private static func loadProfile(from url: URL) -> LocalModelProfile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LocalModelProfile.self, from: data)
    }

    private static func defaultStorageDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FinanceCategorizer", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
}
