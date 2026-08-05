import SwiftUI

struct DuplicateReviewSheet: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @Environment(\.dismiss) private var dismiss

    let groups: [DuplicateMovementGroup]
    let transactions: [Transaction]
    let isScanning: Bool
    let onScan: () -> Void
    let onDismiss: (DuplicateMovementGroup) -> Void
    let onRemove: (DuplicateMovementGroup) -> Void
    let onResolveAll: ([DuplicateMovementGroup]) -> Void

    @State private var pendingConfirmation: DuplicateReviewConfirmation?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppSpacing.medium) {
                    if groups.isEmpty {
                        Label(
                            appLanguage.localized("duplicate.none"),
                            systemImage: "checkmark.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    } else {
                        ForEach(groups) { group in
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
                    }
                }
                .padding(AppSpacing.medium)
            }
            .navigationTitle(LocalizedStringKey("duplicate.reviewAll.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("duplicate.close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
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
                    .disabled(isScanning)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !groups.isEmpty {
                    Button(appLanguage.localized("duplicate.acceptAll")) {
                        pendingConfirmation = .all(groups)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                }
            }
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
