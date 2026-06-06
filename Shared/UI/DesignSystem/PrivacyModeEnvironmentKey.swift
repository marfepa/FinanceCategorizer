import SwiftUI

// MARK: - PrivacyModeEnvironmentKey

/// Custom SwiftUI environment key that propagates the privacy mode toggle
/// throughout the entire view hierarchy.
///
/// Usage — inject at the root (e.g. FinanceCategorizerMacApp):
/// ```swift
/// ContentView()
///     .environment(\.isPrivacyModeEnabled, isPrivacyModeEnabled)
/// ```
///
/// Read in any descendant view:
/// ```swift
/// @Environment(\.isPrivacyModeEnabled) private var isPrivacyModeEnabled
/// ```
struct PrivacyModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isPrivacyModeEnabled: Bool {
        get { self[PrivacyModeKey.self] }
        set { self[PrivacyModeKey.self] = newValue }
    }
}

// MARK: - Amount masking helper

extension View {
    /// Renders `value` as a currency string, replacing each digit with `*`
    /// when privacy mode is enabled in the environment.
    func maskedAmount(_ value: Decimal, currencyCode: String = "EUR") -> String {
        let formatted = value.formatted(.currency(code: currencyCode))
        return formatted  // Callers read the environment themselves; this is a formatting helper.
    }
}

extension Decimal {
    /// Returns a privacy-aware formatted string for this amount.
    func privacyFormatted(hidden: Bool, language: AppLanguage = .currentSelection, currencyCode: String = "EUR") -> String {
        let formatted = language.formatCurrency(self, code: currencyCode)
        guard hidden else { return formatted }
        return String(formatted.map { $0.isNumber ? "*" : $0 })
    }
}
