import SwiftUI

/// Shows a proposed transfer between own accounts: money leaving one account
/// and the same amount arriving in another, with confirm / reject actions.
struct TransferPairRow: View {
    /// At or above this score the pair is labelled "likely" (named accounts plus
    /// a transfer keyword in the description).
    static let likelyThreshold = 0.75

    let proposal: TransferPairProposal
    let language: AppLanguage
    let isPrivacyModeEnabled: Bool
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            side(proposal.outgoing, systemImage: "arrow.up.right.circle.fill", directionKey: "review.transferPair.outgoing")
            side(proposal.incoming, systemImage: "arrow.down.left.circle.fill", directionKey: "review.transferPair.incoming")

            Text(verbatim: evidenceText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !proposal.hasNamedAccounts {
                Label(language.localized("review.transferPair.nameAccountsTip"), systemImage: "lightbulb")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.small) { actions }
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    actions.frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, AppSpacing.xSmall)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: accessibilitySummary))
    }

    @ViewBuilder
    private var actions: some View {
        Button(action: onConfirm) {
            Text(verbatim: language.localized("review.transferPair.confirm"))
                .frame(maxWidth: stackedButtons ? .infinity : nil)
        }
        .appPrimaryGlassButton()
        .controlSize(controlSize)
        .accessibilityLabel(Text(verbatim: language.localized("review.transferPair.confirmContext", routeText)))
        .accessibilityHint(Text(verbatim: language.localized("review.transferPair.confirmHint")))

        Button(action: onDismiss) {
            Text(verbatim: language.localized("review.transferPair.reject"))
                .frame(maxWidth: stackedButtons ? .infinity : nil)
        }
        .appSecondaryGlassButton()
        .controlSize(controlSize)
        .accessibilityLabel(Text(verbatim: language.localized("review.transferPair.rejectContext", routeText)))
        .accessibilityHint(Text(verbatim: language.localized("review.transferPair.rejectHint")))
    }

    @ViewBuilder
    private func side(_ candidate: TransferPairCandidate, systemImage: String, directionKey: String) -> some View {
        let label = HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: candidate.description)
                    .font(.callout)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                Text(verbatim: "\(language.localized(directionKey)) \(accountLabel(candidate)) · \(language.format(date: candidate.bookingDate))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        let amount = Text(verbatim: amountText(candidate))
            .font(.callout.monospacedDigit().weight(.semibold))

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    label
                    amount
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    label
                    Spacer(minLength: AppSpacing.small)
                    amount
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var stackedButtons: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    private var controlSize: ControlSize {
        #if os(iOS)
        .large
        #else
        .small
        #endif
    }

    private func amountText(_ candidate: TransferPairCandidate) -> String {
        candidate.amount.privacyFormatted(hidden: isPrivacyModeEnabled, language: language)
    }

    private func accountLabel(_ candidate: TransferPairCandidate) -> String {
        candidate.accountName ?? language.localized("review.transferPair.unnamedAccount")
    }

    private var routeText: String {
        language.localized(
            "review.transferPair.route",
            accountLabel(proposal.outgoing),
            accountLabel(proposal.incoming)
        )
    }

    private var gapText: String {
        switch proposal.dayGap {
        case 0: return language.localized("review.transferPair.sameDay")
        case 1: return language.localized("review.transferPair.dayGap.one")
        default: return language.localized("review.transferPair.dayGap.other", language.formatInteger(proposal.dayGap))
        }
    }

    private var evidenceText: String {
        let strength = proposal.confidence >= Self.likelyThreshold
            ? language.localized("review.transferPair.likely")
            : language.localized("review.transferPair.possible")
        return "\(strength) · \(gapText)"
    }

    /// One sentence VoiceOver reads before the actions, e.g. "Possible transfer
    /// of 120 € from Openbank to Cajamar, 2 days apart".
    private var accessibilitySummary: String {
        let amount = isPrivacyModeEnabled
            ? language.localized("review.transferPair.hiddenAmount")
            : abs(proposal.amount).privacyFormatted(hidden: false, language: language)
        return language.localized(
            "review.transferPair.accessibilitySummary",
            evidenceText,
            amount,
            routeText,
            proposal.outgoing.description,
            proposal.incoming.description
        )
    }
}
