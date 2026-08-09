import Foundation
import Observation

struct AccountSummary: Identifiable {
    let id: UUID
    let name: String
    let institution: String?
    let currencyCode: String
    let balance: Decimal?
    let balanceAsOf: Date?
    let balanceSource: BalanceSource?
    let isLiability: Bool
    let transactionCount: Int
    let latestActivity: Date?

    var signedBalance: Decimal? {
        balance.map { isLiability ? -$0 : $0 }
    }
}

@MainActor
@Observable
final class AccountsViewModel {
    private(set) var accounts: [AccountSummary] = []
    private(set) var netWorth: Decimal = 0
    var name = ""
    var institution = ""
    var currencyCode = AppConfig.defaultCurrencyCode
    var balanceText = ""
    var isLiability = false
    var statusMessage: String?
    var errorMessage: String?

    func load(using container: AppContainer) {
        do {
            accounts = try container.accountRepository.fetchAll().map { account in
                let latest = try container.transactionRepository.fetchLatest(accountName: account.name)
                return AccountSummary(
                    id: account.id,
                    name: account.name,
                    institution: account.institution,
                    currencyCode: account.currencyCode,
                    balance: account.currentBalance,
                    balanceAsOf: account.balanceAsOf,
                    balanceSource: account.balanceSourceRaw.flatMap(BalanceSource.init(rawValue:)),
                    isLiability: account.isLiability,
                    transactionCount: try container.transactionRepository.count(accountName: account.name),
                    latestActivity: latest?.bookingDate
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            netWorth = accounts.compactMap(\.signedBalance).reduce(.zero, +)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(using container: AppContainer, language: AppLanguage) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = language.localized("accounts.error.name")
            return
        }
        guard let balance = parsedBalance(language: language) else {
            errorMessage = language.localized("accounts.error.balance")
            return
        }

        do {
            let existing = try container.accountRepository.fetchAll().first {
                $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
            }
            let account = existing ?? Account(name: trimmedName)
            account.name = trimmedName
            account.institution = institution.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            account.currencyCode = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            account.currentBalance = abs(balance)
            account.balanceAsOf = .now
            account.balanceSourceRaw = BalanceSource.manual.rawValue
            account.isLiability = isLiability
            try container.accountRepository.save(account)
            statusMessage = language.localized(existing == nil ? "accounts.status.created" : "accounts.status.updated")
            errorMessage = nil
            name = ""
            institution = ""
            balanceText = ""
            isLiability = false
            load(using: container)
            NotificationCenter.default.post(name: AppContainer.importDidFinishNotification, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parsedBalance(language: AppLanguage) -> Decimal? {
        let formatter = NumberFormatter()
        formatter.locale = language.locale
        formatter.numberStyle = .decimal
        return formatter.number(from: balanceText)?.decimalValue
            ?? Decimal(string: balanceText.replacingOccurrences(of: ",", with: "."))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
