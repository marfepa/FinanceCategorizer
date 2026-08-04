import SwiftUI

private struct LiquidGlassRoundedModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    var material: Material
    var tint: Color
    var interactive: Bool
    var shadowRadius: CGFloat
    var shadowY: CGFloat
    var shadowOpacity: Double

    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            content
                .padding(padding)
                .glassEffect(
                    Glass.regular
                        .tint(tint.opacity(0.08))
                        .interactive(interactive),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
        } else {
            content
                .padding(padding)
                .background {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(material)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(
                    color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius,
                    x: 0,
                    y: shadowY
                )
        }
    }
}

private struct LiquidGlassCapsuleModifier: ViewModifier {
    var padding: CGFloat
    var material: Material
    var tint: Color
    var interactive: Bool
    var shadowRadius: CGFloat
    var shadowY: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            content
                .padding(padding)
                .glassEffect(
                    Glass.regular
                        .tint(tint.opacity(0.08))
                        .interactive(interactive),
                    in: Capsule(style: .continuous)
                )
        } else {
            content
                .padding(padding)
                .background {
                    Capsule(style: .continuous)
                        .fill(material)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.09), radius: shadowRadius, x: 0, y: shadowY)
        }
    }
}

extension View {
    /// Wraps the view in a Liquid Glass card surface.
    func glassCard(
        padding: CGFloat = AppLayoutMetrics.contentGap,
        radius: CGFloat = AppRadius.card,
        material: Material = AppMaterials.controlGlass,
        shadowRadius: CGFloat = 14,
        shadowY: CGFloat = 6
    ) -> some View {
        liquidGlassPanel(
            padding: padding,
            radius: radius,
            material: material,
            tint: AppColors.accent,
            shadowRadius: shadowRadius,
            shadowY: shadowY
        )
    }

    /// Applies the hero-sized Liquid Glass surface (larger radius, thicker material).
    func glassHeroCard(padding: CGFloat = AppLayoutMetrics.heroInset) -> some View {
        liquidGlassHero(
            padding: padding,
            tint: .white
        )
    }

    /// Applies a standard content material surface (Native look, less glass).
    func contentCard(
        padding: CGFloat = AppLayoutMetrics.contentGap,
        radius: CGFloat = AppRadius.card
    ) -> some View {
        modifier(ContentCardModifier(padding: padding, radius: radius))
    }

    func liquidGlassPanel(
        padding: CGFloat = AppLayoutMetrics.contentGap,
        radius: CGFloat = AppRadius.card,
        material: Material = AppMaterials.contentMaterial,
        tint: Color = AppColors.accent,
        interactive: Bool = false,
        shadowRadius: CGFloat = 18,
        shadowY: CGFloat = 10,
        shadowOpacity: Double = 0.12
    ) -> some View {
        modifier(LiquidGlassRoundedModifier(
            padding: padding,
            radius: radius,
            material: material,
            tint: tint,
            interactive: interactive,
            shadowRadius: shadowRadius,
            shadowY: shadowY,
            shadowOpacity: shadowOpacity
        ))
    }

    func liquidGlassGrouped(
        padding: CGFloat = AppLayoutMetrics.blockGap,
        radius: CGFloat = AppRadius.panelGroup,
        tint: Color = AppColors.accent
    ) -> some View {
        liquidGlassPanel(
            padding: padding,
            radius: radius,
            material: AppMaterials.groupedGlass,
            tint: tint,
            shadowRadius: 22,
            shadowY: 14,
            shadowOpacity: 0.14
        )
    }

    func liquidGlassHero(
        padding: CGFloat = AppLayoutMetrics.liquidHeroInset,
        tint: Color = AppColors.neutral
    ) -> some View {
        liquidGlassPanel(
            padding: padding,
            radius: AppRadius.hero,
            material: AppMaterials.heroGlass,
            tint: tint,
            shadowRadius: 28,
            shadowY: 16,
            shadowOpacity: 0.16
        )
    }

    func liquidGlassPill(
        padding: CGFloat = 14,
        material: Material = AppMaterials.subtleGlass,
        tint: Color = AppColors.accent,
        interactive: Bool = false,
        shadowRadius: CGFloat = 10,
        shadowY: CGFloat = 6
    ) -> some View {
        modifier(LiquidGlassCapsuleModifier(
            padding: padding,
            material: material,
            tint: tint,
            interactive: interactive,
            shadowRadius: shadowRadius,
            shadowY: shadowY
        ))
    }
}

private struct ContentCardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct LiquidGlassContainer<Content: View>: View {
    let spacing: CGFloat?
    let content: Content

    init(
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

struct GlassPageScaffold<Header: View, Content: View, Background: View>: View {
    let header: Header
    let background: Background
    let content: Content

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder background: () -> Background,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header()
        self.background = background()
        self.content = content()
    }

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) where Background == EmptyView {
        self.header = header()
        self.background = EmptyView()
        self.content = content()
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.sectionGap) {
                    header
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppLayoutMetrics.screenPadding)
            }
        }
    }
}

struct GlassActionStrip<Primary: View, Secondary: View>: View {
    let primary: Primary
    let secondary: Secondary

    init(
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        LiquidGlassContainer(spacing: AppLayoutMetrics.microGap) {
            HStack(alignment: .center, spacing: AppLayoutMetrics.contentGap) {
                HStack(spacing: AppLayoutMetrics.microGap) {
                    primary
                }
                Spacer(minLength: AppLayoutMetrics.contentGap)
                HStack(spacing: AppLayoutMetrics.microGap) {
                    secondary
                }
            }
            .liquidGlassPanel(
                padding: AppLayoutMetrics.contentGap,
                radius: AppRadius.card,
                material: AppMaterials.subtleGlass,
                tint: .white,
                interactive: true,
                shadowRadius: 16,
                shadowY: 8
            )
        }
    }
}

struct GlassInspectorPanel<Primary: View, Advanced: View, Footer: View>: View {
    let title: LocalizedStringKey
    @Binding var isAdvancedExpanded: Bool
    let primary: Primary
    let advanced: Advanced
    let footer: Footer

    init(
        title: LocalizedStringKey,
        isAdvancedExpanded: Binding<Bool>,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder advanced: () -> Advanced,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self._isAdvancedExpanded = isAdvancedExpanded
        self.primary = primary()
        self.advanced = advanced()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
            Text(title)
                .font(AppTypography.sectionTitle)

            ScrollView {
                VStack(alignment: .leading, spacing: AppLayoutMetrics.blockGap) {
                    primary

                    DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                        advanced
                            .padding(.top, AppLayoutMetrics.contentGap)
                    } label: {
                        Text(LocalizedStringKey("Advanced"))
                            .font(.headline)
                    }
                    .tint(.secondary)
                }
                .padding(.bottom, AppLayoutMetrics.sectionGap)
            }

            footer
        }
        .padding(AppLayoutMetrics.sectionGap)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .liquidGlassPanel(
            padding: AppLayoutMetrics.sectionGap,
            radius: AppRadius.panelGroup,
            material: AppMaterials.navigationGlass,
            tint: AppColors.accent,
            shadowRadius: 18,
            shadowY: 10
        )
    }
}
