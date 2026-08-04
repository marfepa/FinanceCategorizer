import SwiftUI

/// Corner radius tokens aligned with macOS 26 Liquid Glass design language.
enum AppRadius {
    /// Inner grouped surfaces and inset cards.
    static let inner: CGFloat = 16
    /// Standard card radius — used for all content cards.
    static let card: CGFloat = 18
    /// Large grouped content shells.
    static let panelGroup: CGFloat = 22
    /// Hero card radius — used for the large hero surfaces.
    static let hero: CGFloat = 26
    /// Chip / pill radius — for stat chips and badges.
    static let chip: CGFloat = 999
    /// Floating pill chrome.
    static let pill: CGFloat = 999
    /// Button radius — matches standard macOS button aesthetics.
    static let button: CGFloat = 12
    /// Sheet / popover radius.
    static let sheet: CGFloat = 24
}
