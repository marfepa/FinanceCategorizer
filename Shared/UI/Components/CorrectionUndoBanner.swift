import SwiftUI

/// Confirmation shown after a review decision is saved. It stays until the
/// next action or until dismissed, so it never times out on VoiceOver or
/// keyboard users. Hosts should attach it with `safeAreaInset(edge: .bottom)`
/// so it never covers list rows or action bars.
struct CorrectionUndoBanner: View {
    /// Changes on every new batch so repeated identical messages are still announced.
    let batchID: UUID
    let message: String
    /// Shown inside the banner so a failed undo is never hidden behind it.
    var errorMessage: String? = nil
    let showsRuleSuggestion: Bool
    let language: AppLanguage
    let onUndo: () -> Void
    let onCreateRule: () -> Void
    let onDismiss: () -> Void

    @ScaledMetric(relativeTo: .callout) private var verticalPadding = AppSpacing.small
    @ScaledMetric(relativeTo: .callout) private var horizontalPadding = AppSpacing.medium

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.small) {
                messageLabel
                Spacer(minLength: AppSpacing.small)
                actionButtons
                dismissButton
            }

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack(alignment: .top, spacing: AppSpacing.small) {
                    messageLabel
                    Spacer(minLength: 0)
                    dismissButton
                }
                HStack(spacing: AppSpacing.small) {
                    Spacer(minLength: 0)
                    actionButtons
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(1)
        .onAppear(perform: announce)
        .onChange(of: batchID) { announce() }
        .onChange(of: errorMessage) { _, newValue in
            if let newValue {
                AccessibilityNotification.Announcement(newValue).post()
            }
        }
    }

    private var messageLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, AppColors.income)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .layoutPriority(1)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if showsRuleSuggestion {
            Button(language.localized("review.undo.createRule"), action: onCreateRule)
                .appSecondaryGlassButton()
                .controlSize(controlSize)
                .accessibilityHint(Text(verbatim: language.localized("review.undo.createRuleHint")))
        }
        Button(language.localized("review.undo.button"), action: onUndo)
            .appPrimaryGlassButton()
            .controlSize(controlSize)
            .accessibilityHint(Text(verbatim: language.localized("review.undo.buttonHint")))
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
                .frame(minWidth: dismissTarget, minHeight: dismissTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .accessibilityLabel(Text(verbatim: language.localized("review.undo.dismiss")))
    }

    private var controlSize: ControlSize {
        #if os(iOS)
        .large
        #else
        .regular
        #endif
    }

    private var dismissTarget: CGFloat {
        #if os(iOS)
        44
        #else
        24
        #endif
    }

    private func announce() {
        var announcement = AttributedString(message)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }
}
