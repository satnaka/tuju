import SwiftUI

/// SwiftUI equivalents of the HeroUI Pro Glass surface and interaction tokens.
/// System material supplies backdrop blur and follows the user's display preferences.
enum HeroUIGlass {
    static let radius: CGFloat = 8
    static let cardRadius = radius * 3
    static let controlFont = Font.subheadline.weight(.medium)

    enum Surface {
        case card, panel, field
    }
}

extension View {
    func heroGlass(_ surface: HeroUIGlass.Surface, radius: CGFloat = HeroUIGlass.cardRadius,
                   focused: Bool = false) -> some View {
        modifier(HeroUIGlassSurface(surface: surface, radius: radius, focused: focused))
    }
}

private struct HeroUIGlassSurface: ViewModifier {
    let surface: HeroUIGlass.Surface
    let radius: CGFloat
    let focused: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let dark = scheme == .dark
        let edge = dark ? Color.white : .black
        content
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(Color(uiColor: .systemBackground))
                    } else {
                        shape.fill(.regularMaterial)
                    }
                    switch surface {
                    case .card:
                        shape.fill(.white.opacity(dark ? 0.04 : 0.80))
                    case .panel:
                        shape.fill(LinearGradient(
                            colors: [JourneyInk.sky.opacity(dark ? 0.05 : 0.75), .white.opacity(dark ? 0.05 : 0.75)],
                            startPoint: .top, endPoint: .bottom
                        ))
                    case .field:
                        shape.fill(dark ? .white.opacity(0.08) : Color(red: 0.02, green: 0.03, blue: 0.08).opacity(0.06))
                    }
                }
                .shadow(color: .black.opacity(surface == .panel ? 0.08 : 0), radius: 14, y: 7)
            }
            .overlay {
                if focused {
                    shape.inset(by: -2).strokeBorder(.tint, lineWidth: 2).allowsHitTesting(false)
                } else if surface == .field || contrast == .increased {
                    shape.strokeBorder(edge.opacity(contrast == .increased ? 0.36 : 0.04), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
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
