import SwiftUI

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        GlassSearchBar(text: $text)
    }
}

struct GlassSearchBar: View {
    @Binding var text: String
    var placeholder: LocalizedStringKey = "Search"

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.title3)
                .frame(maxWidth: .infinity)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .modifier(GlassSearchChrome())
    }
}

struct FloatingGlassSegmentedBar<Option: Hashable & Identifiable>: View {
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Option
    @Namespace private var selectorNamespace

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                segments
            }
        } else {
            segments
        }
    }

    private var segments: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.id) { option in
                let isSelected = selection == option

                Button {
                    withAnimation(.spring(response: 0.56, dampingFraction: 0.82, blendDuration: 0.24)) {
                        selection = option
                    }
                } label: {
                    ZStack {
                        if isSelected {
                            SelectedSegmentCapsule()
                                .padding(0.75)
                                .matchedGeometryEffect(id: "floating-glass-selector", in: selectorNamespace)
                        }

                        Text(title(option))
                            .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.92)
                            .allowsTightening(false)
                            .compositingGroup()
                            .tracking(isSelected ? 0.18 : 0.10)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 11)
                            .frame(minWidth: 70, minHeight: 44)
                    }
                    .frame(maxHeight: .infinity)
                    .clipShape(Capsule(style: .continuous))
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            Capsule(style: .continuous)
                .modifier(RangeBarGlass())
        }
        .clipShape(Capsule(style: .continuous))
        .animation(.spring(response: 0.56, dampingFraction: 0.82, blendDuration: 0.24), value: selection)
    }
}

private struct GlassSearchChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(true), in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

private struct GlassSegmentedGroupChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            content
                .glassEffect(
                    Glass.regular
                        .tint(.white.opacity(0.05)),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.8)
                }
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

private struct SelectedSegmentCapsule: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if #available(macOS 26.0, iOS 26.0, *) {
                Capsule(style: .continuous)
                    .background(Color.white.opacity(0.10), in: Capsule(style: .continuous))
                    .glassEffect(
                        Glass.regular
                            .tint(.white.opacity(0.12))
                            .interactive(true),
                        in: Capsule(style: .continuous)
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                    Color.primary.opacity(0.12),
                                    Color.primary.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(1.1)
                            .blur(radius: 0.35)
                            .blendMode(.screen)
                            .allowsHitTesting(false)
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                    Color.primary.opacity(0.30),
                                    Color.primary.opacity(0.10),
                                    Color.primary.opacity(0.20)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.95
                            )
                    }
                    .shadow(color: Color.primary.opacity(0.05), radius: 4, x: 0, y: -1)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
            } else {
                Capsule(style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.92),
                                    Color.white.opacity(0.78)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        colorScheme == .dark ? Color.white.opacity(0.35) : Color.white.opacity(0.62),
                                        colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.30)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.95
                            )
                    }
                    .shadow(color: colorScheme == .dark ? .clear : .white.opacity(0.16), radius: 3, x: 0, y: -1)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 10, x: 0, y: 4)
            }
        }
        .compositingGroup()
    }
}

private struct RangeBarGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            content
                .background(Color.white.opacity(0.05), in: Capsule(style: .continuous))
                .glassEffect(
                    Glass.regular
                        .tint(.white.opacity(0.07))
                        .interactive(true),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.30),
                                    Color.white.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1.4)
                        .blur(radius: 0.45)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.42),
                                    .white.opacity(0.16),
                                    .white.opacity(0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.95
                        )
                }
                .shadow(color: .white.opacity(0.08), radius: 4, x: 0, y: -1)
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.32),
                                    Color.white.opacity(0.14)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .white.opacity(0.08), radius: 4, x: 0, y: -1)
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
        }
    }
}
