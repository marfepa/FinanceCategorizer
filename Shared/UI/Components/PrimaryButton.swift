import SwiftUI

struct AppPrimaryGlassButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

struct AppSecondaryGlassButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

extension View {
    func appPrimaryGlassButton() -> some View {
        modifier(AppPrimaryGlassButton())
    }

    func appSecondaryGlassButton() -> some View {
        modifier(AppSecondaryGlassButton())
    }
}

struct PrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .appPrimaryGlassButton()
            .controlSize(.regular)
    }
}
