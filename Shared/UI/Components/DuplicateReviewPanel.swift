import SwiftUI

enum DuplicateReviewConfirmation: Identifiable {
    case single(DuplicateMovementGroup)
    case all([DuplicateMovementGroup])

    var id: String {
        switch self {
        case .single(let group):
            return "single-\(group.id)"
        case .all:
            return "all"
        }
    }
}

struct DuplicateReviewPanel: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled

    let groups: [DuplicateMovementGroup]
    let transactions: [Transaction]
    let isScanning: Bool
    let onScan: () -> Void
    let onDismiss: (DuplicateMovementGroup) -> Void
    let onRemove: (DuplicateMovementGroup) -> Void
    let onResolveAll: ([DuplicateMovementGroup]) -> Void

    @State private var pendingConfirmation: DuplicateReviewConfirmation?
    @State private var isShowingFullReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(appLanguage.localized("duplicate.title"))
                        .font(.headline)
                    Text(appLanguage.localized("duplicate.subtitle"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onScan()
                } label: {
                    Label(
                        isScanning
                            ? appLanguage.localized("duplicate.scan.inProgress")
                            : appLanguage.localized("duplicate.scan"),
                        systemImage: "magnifyingglass"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isScanning)
            }

            if groups.isEmpty {
                Label(
                    appLanguage.localized("duplicate.none"),
                    systemImage: "checkmark.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                HStack(spacing: AppSpacing.small) {
                    Button(appLanguage.localized("duplicate.reviewAll")) {
                        isShowingFullReview = true
                    }
                    .buttonStyle(.bordered)

                    Button(appLanguage.localized("duplicate.acceptAll")) {
                        pendingConfirmation = .all(groups)
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }

                ForEach(groups.prefix(4)) { group in
                    DuplicateReviewGroupCard(
                        group: group,
                        transactions: transactions,
                        onKeepSuggested: {
                            pendingConfirmation = .single(group)
                        },
                        onDismiss: {
                            onDismiss(group)
                        }
                    )
                }

                if groups.count > 4 {
                    Text(appLanguage.localized("duplicate.more", appLanguage.formatInteger(groups.count - 4)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppMaterials.contentMaterial)
        )
        .sheet(isPresented: $isShowingFullReview) {
            DuplicateReviewSheet(
                groups: groups,
                transactions: transactions,
                isScanning: isScanning,
                onScan: onScan,
                onDismiss: onDismiss,
                onRemove: onRemove,
                onResolveAll: onResolveAll
            )
        }
        .confirmationDialog(
            LocalizedStringKey(
                pendingConfirmation?.isAll == true
                    ? "duplicate.acceptAll.title"
                    : "duplicate.confirmRemove.title"
            ),
            isPresented: Binding(
                get: { pendingConfirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingConfirmation = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(
                LocalizedStringKey(
                    pendingConfirmation?.isAll == true
                        ? "duplicate.acceptAll.action"
                        : "duplicate.confirmRemove.action"
                ),
                role: .destructive
            ) {
                guard let pendingConfirmation else { return }
                switch pendingConfirmation {
                case .single(let group):
                    onRemove(group)
                case .all(let groups):
                    onResolveAll(groups)
                }
                self.pendingConfirmation = nil
            }
            Button(LocalizedStringKey("Cancel"), role: .cancel) {
                pendingConfirmation = nil
            }
        } message: {
            if pendingConfirmation?.isAll == true {
                Text(LocalizedStringKey("duplicate.acceptAll.message"))
            } else {
                Text(LocalizedStringKey("duplicate.confirmRemove.message"))
            }
        }
    }
}

extension DuplicateReviewConfirmation {
    var isAll: Bool {
        if case .all = self {
            return true
        }
        return false
    }
}

struct DuplicateReviewGroupCard: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled

    let group: DuplicateMovementGroup
    let transactions: [Transaction]
    let onKeepSuggested: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        let members = transactions.filter { group.transactionIDs.contains($0.id) }
        let recommended = members.first(where: { $0.id == group.recommendedKeepID }) ?? members.first

        return VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .top) {
                Label(
                    appLanguage.localized(group.reasonKey),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

                Spacer()

                Text(group.confidence.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(members) { transaction in
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    Image(systemName: transaction.id == recommended?.id ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(transaction.id == recommended?.id ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.rawDescription)
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                        Text(appLanguage.format(date: transaction.bookingDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(transaction.amount.privacyFormatted(
                        hidden: isPrivacyModeEnabled,
                        language: appLanguage,
                        currencyCode: transaction.currencyCode
                    ))
                    .font(.footnote.monospacedDigit())
                }
            }

            if let recommended {
                Text(appLanguage.localized("duplicate.proposal", recommended.rawDescription))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: AppSpacing.small) {
                Button(LocalizedStringKey("duplicate.keepAndRemove")) {
                    onKeepSuggested()
                }
                .buttonStyle(.bordered)

                Button(LocalizedStringKey("duplicate.dismiss")) {
                    onDismiss()
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(AppSpacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.inner, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.7))
        )
    }
}
