import SwiftUI

/// Fixed colors from the app icon; the accent is the user's choice (`AccentChoice`).
enum DeskfocusTheme {
    static let indigo = Color(.sRGB, red: 0.357, green: 0.314, blue: 0.941, opacity: 1)    // #5B50F0
    static let ink = Color(.sRGB, red: 0.110, green: 0.090, blue: 0.278, opacity: 1)       // #1C1747

    /// Hairline used for separators and outlines on glass.
    static let hairline = Color.white.opacity(0.12)

    /// Edge of glass cards and chips, brighter at the top like light falling on glass.
    static let glassStroke = LinearGradient(
        colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Red for ending a session, the same in every accent.
    static let danger = Color(.sRGB, red: 1.0, green: 0.271, blue: 0.227, opacity: 1)  // #FF453A

    /// Overdue labels: a lighter red that reads on dark glass, a deeper one in light menus.
    static func overdue(in colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.sRGB, red: 1.0, green: 0.541, blue: 0.502, opacity: 1)   // #FF8A80
            : Color(.sRGB, red: 0.843, green: 0.0, blue: 0.082, opacity: 1)   // #D70015
    }
}

/// Rounded primary button in the user's accent, as on "Done".
struct DeskfocusPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DeskfocusButtonBody(kind: .primary, configuration: configuration)
    }
}

/// Red button for ending a session without finishing the task.
struct DeskfocusDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DeskfocusButtonBody(kind: .danger, configuration: configuration)
    }
}

/// Quiet translucent button for secondary actions such as "Pause".
struct DeskfocusGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DeskfocusButtonBody(kind: .glass, configuration: configuration)
    }
}

/// Plain button that sinks in while pressed; for round icon buttons such as ▶ and ✓.
struct DeskfocusPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(DeskfocusMotion.press, value: configuration.isPressed)
    }
}

/// Shared look of the text buttons: they brighten under the pointer and sink in while pressed.
/// A view, so it can read the accent from the environment and track the pointer.
private struct DeskfocusButtonBody: View {
    enum Kind {
        case primary
        case danger
        case glass
    }

    @Environment(\.deskfocusAccent) private var accent
    let kind: Kind
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: kind == .glass ? .semibold : .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(background, in: shape)
            .overlay(shape.strokeBorder(edge, lineWidth: 1))
            .shadow(color: shadowColor, radius: configuration.isPressed ? 3 : 8, y: configuration.isPressed ? 1 : 3)
            .brightness(isHovered && !configuration.isPressed ? 0.05 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DeskfocusMotion.press, value: configuration.isPressed)
            .animation(DeskfocusMotion.hover, value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return accent.onAccent
        case .danger: return .white
        case .glass: return .primary
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .primary: return AnyShapeStyle(accent.gradient)
        case .danger: return AnyShapeStyle(DeskfocusTheme.danger.opacity(configuration.isPressed ? 0.75 : 0.9))
        case .glass: return AnyShapeStyle(Color.white.opacity(configuration.isPressed ? 0.2 : 0.12))
        }
    }

    /// Glass gets the top-lit edge; filled buttons a faint highlight along the top.
    private var edge: LinearGradient {
        switch kind {
        case .glass:
            return DeskfocusTheme.glassStroke
        case .primary, .danger:
            return LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0)], startPoint: .top, endPoint: .center)
        }
    }

    private var shadowColor: Color {
        switch kind {
        case .primary: return accent.colors.deep.opacity(0.35)
        case .danger: return DeskfocusTheme.danger.opacity(0.3)
        case .glass: return .clear
        }
    }
}
