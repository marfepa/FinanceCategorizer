import SwiftUI

struct AccountsView: View {
    @Environment(\.appContainer) private var appContainer
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled
    @State private var viewModel = AccountsViewModel()

    var body: some View {
        List {
            Section {
                LabeledContent(LocalizedStringKey("Confirmed net worth")) {
                    Text(viewModel.netWorth.privacyFormatted(
                        hidden: isPrivacyModeEnabled,
                        language: appLanguage
                    ))
                    .font(.title3.monospacedDigit().weight(.semibold))
                }
            }

            Section(LocalizedStringKey("Add or update account")) {
                TextField(LocalizedStringKey("Account name"), text: $viewModel.name)
                TextField(LocalizedStringKey("Financial institution"), text: $viewModel.institution)
                TextField(LocalizedStringKey("Currency"), text: $viewModel.currencyCode)
                TextField(LocalizedStringKey("Current balance"), text: $viewModel.balanceText)
                Toggle(LocalizedStringKey("This account is a liability"), isOn: $viewModel.isLiability)
                Button(LocalizedStringKey("Save account")) {
                    viewModel.save(using: appContainer, language: appLanguage)
                }
                .disabled(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let statusMessage = viewModel.statusMessage {
                Section { Text(statusMessage).foregroundStyle(AppColors.income) }
            }
            if let errorMessage = viewModel.errorMessage {
                Section { Text(errorMessage).foregroundStyle(AppColors.expense) }
            }

            Section(LocalizedStringKey("Accounts")) {
                if viewModel.accounts.isEmpty {
                    Text(LocalizedStringKey("No accounts yet. Associate an import with an account or add one manually."))
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.accounts) { account in
                    accountRow(account)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Accounts"))
        .task { viewModel.load(using: appContainer) }
        .refreshable { viewModel.load(using: appContainer) }
    }

    private func accountRow(_ account: AccountSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name).font(.headline)
                    if let institution = account.institution {
                        Text(institution).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let balance = account.balance {
                    Text(balance.privacyFormatted(
                        hidden: isPrivacyModeEnabled,
                        language: appLanguage,
                        currencyCode: account.currencyCode
                    ))
                    .monospacedDigit()
                    .foregroundStyle(account.isLiability ? AppColors.expense : .primary)
                } else {
                    Text(LocalizedStringKey("Balance pending")).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: AppSpacing.medium) {
                Label(appLanguage.localized("%lld movements", account.transactionCount), systemImage: "list.bullet")
                if let latestActivity = account.latestActivity {
                    Label(appLanguage.format(date: latestActivity), systemImage: "clock")
                }
                if account.isLiability {
                    Label(LocalizedStringKey("Liability"), systemImage: "creditcard")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppSpacing.xSmall)
    }
}
