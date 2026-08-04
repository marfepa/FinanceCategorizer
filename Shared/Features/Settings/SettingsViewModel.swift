import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var aiEnabled = FeatureFlags.aiSuggestionsEnabled {
        didSet { FeatureFlags.aiSuggestionsEnabled = aiEnabled }
    }
    var foundationModelsEnabled = FeatureFlags.foundationModelsEnabled {
        didSet { FeatureFlags.foundationModelsEnabled = foundationModelsEnabled }
    }
    var autoAcceptThreshold = AppConfig.autoCategorizationThreshold
    var softAcceptThreshold = AppConfig.softAutoCategorizationThreshold
    var reviewThreshold = AppConfig.suggestionThreshold
    var modelReady = false
    var learnedExampleCount = 0
    var readyCategoryCount = 0
    var totalCategoryCount = 0
    private(set) var readiness: LocalModelReadiness?
    private(set) var readinessErrorMessage: String?

    func load(using container: AppContainer) {
        do {
            let readiness = try container.localModelManager.readinessStatus()
            self.readiness = readiness
            readinessErrorMessage = nil
            modelReady = readiness.isReady
            learnedExampleCount = readiness.learnedExampleCount
            readyCategoryCount = readiness.readyCategoryCount
            totalCategoryCount = readiness.totalCategoryCount
        } catch {
            readiness = nil
            readinessErrorMessage = error.localizedDescription
            modelReady = false
            learnedExampleCount = 0
            readyCategoryCount = 0
            totalCategoryCount = 0
        }
    }

    func localizedModelStatusTitle(language: AppLanguage) -> String {
        guard let readiness else {
            return language.localized("settings.ml.unavailable.title")
        }

        switch readiness.state {
        case .ready:
            return language.localized("settings.ml.ready.title")
        case .noModel, .needsMoreExamples:
            return language.localized("settings.ml.learning.title")
        }
    }

    func localizedModelStatusDetail(language: AppLanguage) -> String {
        if let readinessErrorMessage {
            return readinessErrorMessage
        }

        guard let readiness else {
            return language.localized("settings.ml.unavailable.detail")
        }

        switch readiness.state {
        case .noModel:
            return language.localized("settings.ml.noModel.detail")
        case .ready:
            return language.localized("settings.ml.ready.detail")
        case .needsMoreExamples(let missingExamples, let missingCategories):
            return language.localized(
                "settings.ml.learning.detail",
                language.formatInteger(missingExamples),
                language.formatInteger(missingCategories)
            )
        }
    }

    func localizedLastUpdatedText(language: AppLanguage) -> String {
        if let updatedAt = readiness?.lastUpdatedAt {
            return language.format(date: updatedAt, dateStyle: .medium, timeStyle: .short)
        }

        return readinessErrorMessage == nil
            ? language.localized("settings.ml.notTrainedYet")
            : language.localized("settings.ml.unavailable")
    }
}
