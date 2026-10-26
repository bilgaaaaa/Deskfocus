import SwiftUI

extension AccentChoice {
    /// Light and deep shade of the accent; the amber pair matches the app icon's ring.
    var colors: (light: Color, deep: Color) {
        switch self {
        case .amber: return (Self.rgb(0xFFC857), Self.rgb(0xFF6A3D))
        case .coral: return (Self.rgb(0xFF9A8B), Self.rgb(0xFF4E50))
        case .pink: return (Self.rgb(0xFFA8D5), Self.rgb(0xF0508C))
        case .violet: return (Self.rgb(0xC3B5FF), Self.rgb(0x8A6CFF))
        case .sky: return (Self.rgb(0x9FDBFF), Self.rgb(0x3D8BFF))
        case .mint: return (Self.rgb(0xA6F4D8), Self.rgb(0x2BC48A))
        case .lime: return (Self.rgb(0xE4F77A), Self.rgb(0x9BCB2D))
        case .white: return (Color.white, Self.rgb(0xD8D8E0))
        }
    }

    /// Labels such as "MONDAY" and "Today".
    var color: Color { colors.light }

    /// Buttons, the play glyph and the focus ring.
    var gradient: LinearGradient {
        LinearGradient(colors: [colors.light, colors.deep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Text and icons drawn on top of the accent gradient; dark ink reads on every light accent.
    var onAccent: Color { DeskfocusTheme.ink }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private struct DeskfocusAccentKey: EnvironmentKey {
    static let defaultValue: AccentChoice = .amber
}

extension EnvironmentValues {
    /// The user's accent, set once at the root of every Deskfocus surface.
    var deskfocusAccent: AccentChoice {
        get { self[DeskfocusAccentKey.self] }
        set { self[DeskfocusAccentKey.self] = newValue }
    }
}
