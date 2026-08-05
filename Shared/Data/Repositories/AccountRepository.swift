import Foundation
import SwiftData

@MainActor
final class AccountRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func fetchAll() throws -> [Account] {
        try makeContext().fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    func save(_ account: Account) throws {
        let context = makeContext()
        let accountID = account.id
        if let existing = try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.id == accountID })).first {
            existing.name = account.name
            existing.institution = account.institution
            existing.currencyCode = account.currencyCode
            existing.currentBalance = account.currentBalance
            existing.balanceAsOf = account.balanceAsOf
            existing.balanceSourceRaw = account.balanceSourceRaw
            existing.isLiability = account.isLiability
        } else {
            context.insert(account)
        }
        try context.save()
    }

    func saveBalance(
        accountID: UUID?,
        name: String,
        balance: Decimal,
        asOf: Date = .now,
        isLiability: Bool = false
    ) throws {
        let context = makeContext()
        let account: Account?
        if let accountID {
            let targetID = accountID
            account = try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.id == targetID })).first
        } else {
            let targetName = name
            account = try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.name == targetName })).first
        }

        if let account {
            account.name = name
            account.currentBalance = balance
            account.balanceAsOf = asOf
            account.balanceSourceRaw = BalanceSource.manual.rawValue
            account.isLiability = isLiability
        } else {
            context.insert(Account(
                name: name,
                currentBalance: balance,
                balanceAsOf: asOf,
                balanceSourceRaw: BalanceSource.manual.rawValue,
                isLiability: isLiability
            ))
        }
        try context.save()
    }
}
