import SwiftUI

struct MacSettingsView: View {
    @Environment(\.appContainer) private var appContainer
    @State private var viewModel = SettingsViewModel()
    @AppStorage("isPrivacyModeEnabled") private var isPrivacyModeEnabled = false
    @AppStorage("payrollCutoffDay") private var payrollCutoffDay = 25
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english

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
                    .foregroundStyle(viewModel.modelReady ? .green : .orange)

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
                }

                Text(LocalizedStringKey("Automatic categorization improves as you correct more movements, but the app should never promise 100% accuracy."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(LocalizedStringKey("Artificial Intelligence")) {
                Toggle(LocalizedStringKey("Enable AI suggestions"), isOn: $viewModel.aiEnabled)
                Toggle(LocalizedStringKey("Enable Foundation Models when available"), isOn: $viewModel.foundationModelsEnabled)
                LabeledContent(LocalizedStringKey("Auto-accept threshold")) {
                    Text(appLanguage.formatNumber(viewModel.autoAcceptThreshold))
                        .foregroundStyle(.secondary)
                }
                LabeledContent(LocalizedStringKey("Soft-accept threshold")) {
                    Text(appLanguage.formatNumber(viewModel.softAcceptThreshold))
                        .foregroundStyle(.secondary)
                }
                LabeledContent(LocalizedStringKey("Review threshold")) {
                    Text(appLanguage.formatNumber(viewModel.reviewThreshold))
                        .foregroundStyle(.secondary)
                }
                Text(LocalizedStringKey("The deterministic engine is the primary categorization path. AI is only used for ambiguous transactions."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(LocalizedStringKey("Privacy")) {
                Toggle(LocalizedStringKey("Enable privacy mode (hide amounts)"), isOn: $isPrivacyModeEnabled)
                Text(LocalizedStringKey("When enabled, all monetary amounts are masked with asterisks across the entire app."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(LocalizedStringKey("Payroll")) {
                Stepper(
                    appLanguage.localized("Payroll alert day: %lld", payrollCutoffDay),
                    value: $payrollCutoffDay,
                    in: 22...31
                )
                Text(appLanguage.localized("Income gap alerts start after day %lld. Budget reports move ordinary late payroll to the next month and keep estimated extras in the booking month.", payrollCutoffDay))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(LocalizedStringKey("Import")) {
                Text(LocalizedStringKey("Supported formats: CSV, XLSX, PDF (Openbank digital statements)."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Section(LocalizedStringKey("Automation")) {
                NavigationLink(LocalizedStringKey("Management of Rules")) {
                    MacRulesView()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(LocalizedStringKey("Settings"))
        .task(id: appLanguage) {
            viewModel.load(using: appContainer)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppContainer.importDidFinishNotification)) { _ in
            viewModel.load(using: appContainer)
        }
    }
}
