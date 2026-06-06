import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum AppColors {
    // Accent — uses the system tint so it adapts to the user's accent color preference.
    static let accent: Color = .accentColor

    // Semantic backgrounds
    #if os(macOS)
    static let background: Color = Color(nsColor: .windowBackgroundColor)
    static let cardBackground: Color = Color(nsColor: .controlBackgroundColor).opacity(0.6)
    #else
    static let background: Color = Color(uiColor: .systemBackground)
    static let cardBackground: Color = Color(uiColor: .secondarySystemBackground).opacity(0.6)
    #endif

    // Financial semantics
    #if os(macOS)
    static let income: Color = Color(nsColor: .systemGreen)
    static let expense: Color = Color(nsColor: .systemRed)
    static let neutral: Color = Color(nsColor: .systemBlue)
    static let warning: Color = Color(nsColor: .systemOrange)
    #else
    static let income: Color = Color(uiColor: .systemGreen)
    static let expense: Color = Color(uiColor: .systemRed)
    static let neutral: Color = Color(uiColor: .systemBlue)
    static let warning: Color = Color(uiColor: .systemOrange)
    #endif

    // Glass surface — use .regularMaterial / .ultraThinMaterial directly in views;
    // this alias keeps the symbol for legacy call-sites.
    static let glass = Color.primary.opacity(0.04)
}
