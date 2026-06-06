import SwiftUI

struct AppleAIContextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english

    let surface: AppleAISurface

    @State private var selectedIntent: AppleAIIntent?
    @State private var result: AppleAIActionResult?
    @State private var isRunning = false
    @State private var errorMessage: String?

    private let service = AppleAIGlobalActionService()

    private var actions: [AppleAIIntent] {
        AppleAIIntent.actions(for: surface)
    }

    var body: some View {
        HSplitView {
            sidebar
            detail
        }
        .frame(minWidth: 920, minHeight: 560)
        .onAppear {
            if selectedIntent == nil {
                selectedIntent = actions.first
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Label(LocalizedStringKey("Apple AI"), systemImage: "sparkles")
                    .font(AppTypography.sectionTitle)
                Spacer()
                Button(appLanguage.localized("Cancel")) {
                    dismiss()
                }
            }

            Text(appLanguage.localized("appleAI.currentScreen", surface.title(language: appLanguage)))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                ForEach(actions) { action in
                    actionButton(for: action)
                }
            }

            Spacer()

            PrimaryButton(title: LocalizedStringKey(isRunning ? "appleAI.generating" : "appleAI.runAction")) {
                Task {
                    await runSelectedAction()
                }
            }
            .disabled(selectedIntent == nil || isRunning)
        }
        .padding(AppSpacing.large)
        .background(AppMaterials.sidebar, in: Rectangle())
        .frame(minWidth: 300, idealWidth: 320, maxWidth: 340)
    }

    private func actionButton(for action: AppleAIIntent) -> some View {
        Button {
            selectedIntent = action
            errorMessage = nil
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.small) {
                Image(systemName: action.systemImage)
                    .frame(width: 20)
                    .foregroundStyle(selectedIntent == action ? .white : .accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title(language: appLanguage))
                        .font(.headline)
                        .foregroundStyle(selectedIntent == action ? .white : .primary)
                    Text(action.subtitle(language: appLanguage))
                        .font(.caption)
                        .foregroundStyle(selectedIntent == action ? .white.opacity(0.86) : .secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selectedIntent == action ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                if let intent = selectedIntent {
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(intent.title(language: appLanguage))
                            .font(AppTypography.displayTitle)
                        Text(intent.subtitle(language: appLanguage))
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }

                    if let result {
                        resultView(result)
                    } else {
                        emptyState(intent: intent)
                    }
                } else {
                    ContentUnavailableView(
                        appLanguage.localized("appleAI.noActionSelected"),
                        systemImage: "sparkles",
                        description: Text(appLanguage.localized("appleAI.selectAction"))
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                }
            }
            .padding(AppSpacing.large)
        }
        .background(.windowBackground)
    }

    @ViewBuilder
    private func emptyState(intent: AppleAIIntent) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(spacing: AppSpacing.medium) {
                Image(systemName: intent.systemImage)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                Text(appLanguage.localized("appleAI.emptyState.description"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity)
            .glassHeroCard()

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(appLanguage.localized("appleAI.whatItWillDo"))
                    .font(AppTypography.sectionTitle)
                Text(intent.subtitle(language: appLanguage))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func resultView(_ result: AppleAIActionResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(result.title)
                    .font(AppTypography.sectionTitle)
                Text(result.summary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .glassCard(padding: AppSpacing.large)

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(appLanguage.localized("appleAI.actions"))
                    .font(AppTypography.sectionTitle)

                ForEach(Array(result.bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .top, spacing: AppSpacing.small) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 2)
                        Text(bullet)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(AppSpacing.medium)
                    .background(AppMaterials.thin, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            HStack {
                Spacer()
                PrimaryButton(title: LocalizedStringKey(isRunning ? "appleAI.generating" : "appleAI.regenerate")) {
                    Task {
                        await runSelectedAction()
                    }
                }
                .disabled(selectedIntent == nil || isRunning)
            }
        }
    }

    private func runSelectedAction() async {
        guard let selectedIntent else { return }

        isRunning = true
        errorMessage = nil

        let output = await service.run(
            selectedIntent,
            surface: surface,
            using: appContainer,
            language: appLanguage
        )

        result = output
        isRunning = false
    }
}
