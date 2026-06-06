import SwiftUI

struct IOSReviewQueueView: View {
    @Environment(\.appContainer) private var appContainer
    @State private var viewModel = ReviewQueueViewModel()

    var body: some View {
        List(viewModel.transactions) { transaction in
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(transaction.rawDescription)
                Text(transaction.categorizationReason ?? "Pending review")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Review")
        .onAppear {
            viewModel.load(using: appContainer)
        }
    }
}
