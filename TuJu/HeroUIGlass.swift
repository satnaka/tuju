import SwiftUI

enum HeroUIGlass {
    static let radius: CGFloat = 8
    static let cardRadius = radius * 3
    static let controlFont = Font.subheadline.weight(.medium)

    enum Surface {
        case card, panel, floating, control
    }
}

extension View {
    func heroGlass(_ surface: HeroUIGlass.Surface, radius: CGFloat = HeroUIGlass.cardRadius,
                   focused: Bool = false) -> some View {
        modifier(HeroUIGlassSurface(surface: surface, radius: radius, focused: focused))
    }

    @ViewBuilder
    func heroGlassGroup() -> some View {
        if #available(iOS 26, macCatalyst 26, *) {
            GlassEffectContainer(spacing: 0) { self }
        } else {
            self
        }
    }
}

private struct HeroUIGlassSurface: ViewModifier {
    let surface: HeroUIGlass.Surface
    let radius: CGFloat
    let focused: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let needsOpaqueSurface = reduceTransparency || contrast == .increased
        Group {
            if #available(iOS 26, macCatalyst 26, *),
               (surface == .floating || surface == .control), !needsOpaqueSurface {
                content.glassEffect(.regular.interactive(surface == .control && !reduceMotion), in: shape)
            } else {
                content.background {
                    if needsOpaqueSurface {
                        shape.fill(Color(uiColor: .systemBackground))
                    } else {
                        materialBackground(shape)
                    }
                }
            }
        }
        .overlay {
            if focused {
                shape.inset(by: -2).strokeBorder(.tint, lineWidth: 2).allowsHitTesting(false)
            } else if contrast == .increased {
                shape.strokeBorder(Color.primary.opacity(0.60), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private func materialBackground(_ shape: RoundedRectangle) -> some View {
        let dark = scheme == .dark
        return ZStack {
            shape.fill(.regularMaterial)
            switch surface {
            case .card:
                shape.fill(.white.opacity(dark ? 0.04 : 0.80))
            case .panel:
                shape.fill(LinearGradient(
                    colors: [JourneyInk.sky.opacity(dark ? 0.05 : 0.75), .white.opacity(dark ? 0.05 : 0.75)],
                    startPoint: .top, endPoint: .bottom
                ))
            case .floating, .control:
                EmptyView()
            }
        }
        .shadow(color: .black.opacity(surface == .panel ? 0.08 : 0), radius: 14, y: 7)
    }
}

struct HeroUIGlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .overlay {
                if focused {
                    RoundedRectangle(cornerRadius: HeroUIGlass.cardRadius, style: .continuous)
                        .inset(by: -2).strokeBorder(.tint, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: configuration.isPressed)
    }
}
