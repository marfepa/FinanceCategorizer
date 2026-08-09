import SwiftData

enum FinanceSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
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

enum FinanceMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [FinanceSchemaV1.self]
    static let stages: [MigrationStage] = []
}

enum FinanceSchema {
    static let models = FinanceSchemaV1.models
    static let schema = Schema(versionedSchema: FinanceSchemaV1.self)
}
