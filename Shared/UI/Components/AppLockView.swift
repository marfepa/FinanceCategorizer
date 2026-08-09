import SwiftUI

struct AppLockView: View {
    let viewModel: AppLockViewModel
    let language: AppLanguage

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.large) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(AppColors.accent)

                VStack(spacing: AppSpacing.small) {
                    Text(LocalizedStringKey("Finance Categorizer is locked"))
                        .font(AppTypography.screenTitle)
                    Text(LocalizedStringKey("Authenticate to access your financial information."))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await viewModel.authenticate(reason: language.localized("appLock.reason"))
                    }
                } label: {
                    if viewModel.isAuthenticating {
                        ProgressView()
                    } else {
                        Label(LocalizedStringKey("Unlock"), systemImage: "faceid")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isAuthenticating)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppColors.expense)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(AppSpacing.xLarge)
            .frame(maxWidth: 460)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LocalizedStringKey("Finance Categorizer is locked"))
    }
}
