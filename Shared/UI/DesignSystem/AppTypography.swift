import SwiftUI

enum AppTypography {
    /// Large hero numbers — e.g. net balance in the Dashboard hero card.
    static let heroNumber = Font.system(size: 44, weight: .bold, design: .rounded)
    /// Section display title — e.g. "Dashboard", "Financial Explorer".
    static let displayTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    /// Screen-level title (nav bars, modals).
    static let screenTitle = Font.title2.weight(.semibold)
    /// Card/section heading.
    static let sectionTitle = Font.headline
    /// Default body.
    static let body = Font.body
    /// Monospaced digits for amounts in lists.
    static let amount = Font.body.monospacedDigit()
    /// Caption for labels and secondary context.
    static let caption = Font.caption
}

