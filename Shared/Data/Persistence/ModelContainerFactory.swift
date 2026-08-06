import Foundation
import SwiftData

enum ModelContainerFactory {
    @MainActor
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(FinanceSchema.models)
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        if inMemory {
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfiguration])
            } catch {
                fatalError("Failed to create in-memory ModelContainer: \(error)")
            }
        }

        let storeURL = persistentStoreURL()
        let persistentConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [persistentConfiguration])
        } catch {
            NSLog("FinanceCategorizer: failed to open persistent SwiftData store at %@. Preserving store files and stopping instead of hiding the failure behind an empty store. Error: %@", storeURL.path, String(describing: error))

            do {
                try backupPersistentStoreFiles(at: storeURL)
            } catch {
                NSLog("FinanceCategorizer: failed to create recovery backup for persistent SwiftData store. Error: %@", String(describing: error))
            }

            // Never hide a persistence/migration failure behind an empty
            // in-memory store: that makes the user's data appear deleted.
            fatalError("Failed to open persistent FinanceCategorizer store at \(storeURL.path). A recovery backup was preserved.")
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

    private static func backupPersistentStoreFiles(at storeURL: URL) throws {
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
    }

    private static func recoveryBackupName(date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return "store-backup-\(formatter.string(from: date).replacingOccurrences(of: ":", with: "-"))"
    }
}
