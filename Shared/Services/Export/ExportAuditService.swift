import Foundation

struct ExportAuditEntry: Codable, Equatable {
    let exportedAt: Date
    let privacyMode: ExportService.PrivacyMode
    let transactionCount: Int
}

final class ExportAuditService {
    private let defaults: UserDefaults
    private let storageKey = "exportAuditEntries"
    private let maximumEntries = 50

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(privacyMode: ExportService.PrivacyMode, transactionCount: Int, at date: Date = .now) {
        var updated = entries()
        updated.insert(
            ExportAuditEntry(exportedAt: date, privacyMode: privacyMode, transactionCount: transactionCount),
            at: 0
        )
        if updated.count > maximumEntries {
            updated.removeLast(updated.count - maximumEntries)
        }
        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func entries() -> [ExportAuditEntry] {
        guard let data = defaults.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([ExportAuditEntry].self, from: data) else {
            return []
        }
        return entries
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}
