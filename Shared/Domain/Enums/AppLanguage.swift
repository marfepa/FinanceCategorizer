import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case spanish = "es"
    
    public var id: String { self.rawValue }
    
    public var title: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
    
    public var locale: Locale {
        Locale(identifier: self.rawValue)
    }
}

extension AppLanguage {
    static var currentSelection: AppLanguage {
        guard let rawValue = UserDefaults.standard.string(forKey: "appLanguage"),
              let language = AppLanguage(rawValue: rawValue) else {
            return .english
        }
        return language
    }

    private static var currentModuleBundle: Bundle {
        class BundleToken {}
        return Bundle(for: BundleToken.self)
    }

    private static var fallbackBundle: Bundle {
        let moduleBundle = currentModuleBundle
        if let path = moduleBundle.path(forResource: AppLanguage.english.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return moduleBundle
    }

    private var bundle: Bundle {
        let moduleBundle = Self.currentModuleBundle
        if let path = moduleBundle.path(forResource: rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Self.fallbackBundle
    }

    func localized(_ key: String) -> String {
        let fallback = Self.fallbackBundle.localizedString(forKey: key, value: key, table: nil)
        let localizedValue = bundle.localizedString(forKey: key, value: fallback, table: nil)
        return localizedValue == key ? fallback : localizedValue
    }

    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: localized(key), locale: locale, arguments: arguments)
    }

    func format(date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .none) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    func formatCurrency(_ value: Decimal, code: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    func formatPercent(_ value: Double, fractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func formatNumber<T: BinaryFloatingPoint>(_ value: T, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: Double(value))) ?? "\(value)"
    }

    func formatNumber(_ value: Decimal, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    func formatInteger(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
