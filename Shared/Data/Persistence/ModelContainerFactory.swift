import Foundation
import SwiftData

struct PersistenceRecoveryIssue: Identifiable {
    let id = UUID()
    let storeURL: URL
    let backupDirectory: URL?
    let underlyingError: String
}

struct ModelContainerSetup {
    let container: ModelContainer
    let recoveryIssue: PersistenceRecoveryIssue?
}

enum ModelContainerFactory {
    @MainActor
    static func make(inMemory: Bool = false, customStoreURL: URL? = nil) -> ModelContainerSetup {
        let schema = FinanceSchema.schema
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        if inMemory {
            do {
                return ModelContainerSetup(
                    container: try ModelContainer(
                        for: schema,
                        migrationPlan: FinanceMigrationPlan.self,
                        configurations: [memoryConfiguration]
                    ),
                    recoveryIssue: nil
                )
            } catch {
                fatalError("Failed to create in-memory ModelContainer: \(error)")
            }
        }

        let storeURL = customStoreURL ?? persistentStoreURL()
        let persistentConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return ModelContainerSetup(
                container: try ModelContainer(
                    for: schema,
                    migrationPlan: FinanceMigrationPlan.self,
                    configurations: [persistentConfiguration]
                ),
                recoveryIssue: nil
            )
        } catch {
            NSLog("FinanceCategorizer: failed to open persistent SwiftData store at %@. Preserving store files and entering visible recovery mode. Error: %@", storeURL.path, String(describing: error))

            let backupDirectory: URL?
            do {
                backupDirectory = try backupPersistentStoreFiles(at: storeURL)
            } catch {
                NSLog("FinanceCategorizer: failed to create recovery backup for persistent SwiftData store. Error: %@", String(describing: error))
                backupDirectory = nil
            }

            do {
                let recoveryContainer = try ModelContainer(
                    for: schema,
                    migrationPlan: FinanceMigrationPlan.self,
                    configurations: [memoryConfiguration]
                )
                return ModelContainerSetup(
                    container: recoveryContainer,
                    recoveryIssue: PersistenceRecoveryIssue(
                        storeURL: storeURL,
                        backupDirectory: backupDirectory,
                        underlyingError: error.localizedDescription
                    )
                )
            } catch {
                fatalError("Failed to create recovery ModelContainer: \(error)")
            }
        }
    }

    private static func persistentStoreURL() -> URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FinanceCategorizer", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("FinanceCategorizer", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        } catch {
            fatalError("Failed to create application support directory at \(baseDirectory.path): \(error)")
        }
        return baseDirectory.appendingPathComponent("FinanceCategorizer.store")
    }

    private static func backupPersistentStoreFiles(at storeURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let sidecarExtensions = ["", "-shm", "-wal"]
        let backupDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("RecoveryBackups", isDirectory: true)
            .appendingPathComponent(recoveryBackupName(), isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        for suffix in sidecarExtensions {
            let url = suffix.isEmpty ? storeURL : URL(fileURLWithPath: storeURL.path + suffix)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.copyItem(at: url, to: backupDirectory.appendingPathComponent(url.lastPathComponent))
            }
        }
        return backupDirectory
    }

    private static func recoveryBackupName(date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return "store-backup-\(formatter.string(from: date).replacingOccurrences(of: ":", with: "-"))"
    }
}
