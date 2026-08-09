import SwiftUI

struct IOSSettingsView: View {
    @Environment(\.appContainer) private var appContainer
    @State private var viewModel = SettingsViewModel()
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled = false
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled = false

    var body: some View {
        Form {
            Section(LocalizedStringKey("Language")) {
                Picker(LocalizedStringKey("Language"), selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
            }

            Section(LocalizedStringKey("Local ML Readiness")) {
                Label(viewModel.localizedModelStatusTitle(language: appLanguage), systemImage: viewModel.modelReady ? "checkmark.seal.fill" : "hourglass")
                    .foregroundStyle(viewModel.modelReady ? AppColors.income : AppColors.warning)
                Text(viewModel.localizedModelStatusDetail(language: appLanguage))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                LabeledContent(LocalizedStringKey("Learned examples")) {
                    Text(appLanguage.formatInteger(viewModel.learnedExampleCount))
                }
                LabeledContent(LocalizedStringKey("Covered categories")) {
                    Text("\(appLanguage.formatInteger(viewModel.readyCategoryCount))/\(appLanguage.formatInteger(max(viewModel.totalCategoryCount, 1)))")
                }
                LabeledContent(LocalizedStringKey("Last update")) {
                    Text(viewModel.localizedLastUpdatedText(language: appLanguage))
                        .foregroundStyle(.secondary)
                }
            }

            Section(LocalizedStringKey("Artificial Intelligence")) {
                Toggle(LocalizedStringKey("Enable AI suggestions"), isOn: $viewModel.aiEnabled)
                Toggle(LocalizedStringKey("Enable Foundation Models when available"), isOn: $viewModel.foundationModelsEnabled)
                LabeledContent(LocalizedStringKey("Auto-accept threshold")) {
                    Text(appLanguage.formatNumber(viewModel.autoAcceptThreshold))
                }
                LabeledContent(LocalizedStringKey("Soft-accept threshold")) {
                    Text(appLanguage.formatNumber(viewModel.softAcceptThreshold))
                }
                LabeledContent(LocalizedStringKey("Review threshold")) {
                    Text(appLanguage.formatNumber(viewModel.reviewThreshold))
                }
            }

            Section(LocalizedStringKey("Privacy")) {
                Toggle(LocalizedStringKey("Enable privacy mode (hide amounts)"), isOn: $isPrivacyModeEnabled)
                Toggle(LocalizedStringKey("Require authentication to open the app"), isOn: $isAppLockEnabled)
                Text(LocalizedStringKey("When app lock is enabled, authentication is required after the app leaves the foreground."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(LocalizedStringKey("Export history")) {
                ExportAuditHistoryView(language: appLanguage)
            }
        }
        .navigationTitle(LocalizedStringKey("Settings"))
        .task(id: appLanguage) {
            viewModel.load(using: appContainer)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            viewModel.load(using: appContainer)
        }
    }
}
