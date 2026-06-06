import SwiftUI

struct LoadingView: View {
    let title: LocalizedStringKey

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            ProgressView()
            Text(title)
                .font(AppTypography.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.large)
    }
}
