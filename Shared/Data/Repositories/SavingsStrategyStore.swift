import Foundation

@MainActor
final class SavingsStrategyStore {
    static let storageKey = "savingsStrategyConfig"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SavingsStrategyConfig {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .default
        }
        return (try? decoder.decode(SavingsStrategyConfig.self, from: data)) ?? .default
    }

    func save(_ config: SavingsStrategyConfig) {
        guard let data = try? encoder.encode(config) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
