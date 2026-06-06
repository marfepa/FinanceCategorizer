import SwiftUI

/// Background material tokens for macOS 26 Liquid Glass surfaces.
///
/// We follow a 3-layer surface strategy:
/// 1. ControlGlass: Interactive surfaces (buttons, drop zones).
/// 2. NavigationGlass: Chrome and navigation (sidebars, toolbars).
/// 3. ContentMaterial: Data and content areas (dashboard cards, lists).
enum AppMaterials {
    // --- Strategy Tokens ---
    
    /// Interactive controls look — usually uses `.glassEffect` but we keep the material for fallback.
    static let controlGlass: Material = .regularMaterial
    /// Navigation and structural chrome.
    static let navigationGlass: Material = .thinMaterial
    /// Primary content layer material.
    static let contentMaterial: Material = .regularMaterial
    /// Large hero surfaces with deeper diffusion.
    static let heroGlass: Material = .thickMaterial
    /// Grouped panels that should feel lighter than heroes.
    static let groupedGlass: Material = .thinMaterial
    /// Subtle inset surfaces inside a larger glass section.
    static let subtleGlass: Material = .ultraThinMaterial
    
    // --- Legacy Tokens (to be phased out or mapped) ---
    static let card: Material = contentMaterial
    static let hero: Material = heroGlass
    static let sidebar: Material = .thinMaterial
    static let thin: Material = subtleGlass
    static let sheet: Material = .regularMaterial
}
