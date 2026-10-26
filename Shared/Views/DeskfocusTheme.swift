import SwiftUI

/// Colors and gradients from the app icon, used by every Deskfocus surface.
enum DeskfocusTheme {
    static let amber = Color(.sRGB, red: 1.0, green: 0.784, blue: 0.341, opacity: 1)       // #FFC857
    static let orange = Color(.sRGB, red: 1.0, green: 0.416, blue: 0.239, opacity: 1)      // #FF6A3D
    static let indigo = Color(.sRGB, red: 0.357, green: 0.314, blue: 0.941, opacity: 1)    // #5B50F0
    static let ink = Color(.sRGB, red: 0.110, green: 0.090, blue: 0.278, opacity: 1)       // #1C1747

    /// The focus ring and primary buttons.
    static let focusGradient = LinearGradient(colors: [amber, orange], startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Hairline used for separators and outlines on glass.
    static let hairline = Color.white.opacity(0.12)
}

/// Rounded, amber-to-orange primary button, as on the "Up next" card and "Done".
struct DeskfocusPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(DeskfocusTheme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(DeskfocusTheme.focusGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Quiet translucent button for secondary actions such as "Pause".
struct DeskfocusGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(Color.white.opacity(configuration.isPressed ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.22)))
    }
}
