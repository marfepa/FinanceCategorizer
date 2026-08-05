import SwiftData

enum FinanceSchema {
    static let models: [any PersistentModel.Type] = [
        Transaction.self,
        Account.self,
        SavingsGoal.self,
        Category.self,
        Merchant.self,
        ImportBatch.self,
        Rule.self,
        UserCorrection.self,
        Insight.self,
        Budget.self
    ]
}
