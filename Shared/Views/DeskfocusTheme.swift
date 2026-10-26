import SwiftUI

/// Fixed colors from the app icon; the accent is the user's choice (`AccentChoice`).
enum DeskfocusTheme {
    static let indigo = Color(.sRGB, red: 0.357, green: 0.314, blue: 0.941, opacity: 1)    // #5B50F0
    static let ink = Color(.sRGB, red: 0.110, green: 0.090, blue: 0.278, opacity: 1)       // #1C1747

    /// Hairline used for separators and outlines on glass.
    static let hairline = Color.white.opacity(0.12)

    /// Red for ending a session, the same in every accent.
    static let danger = Color(.sRGB, red: 1.0, green: 0.271, blue: 0.227, opacity: 1)  // #FF453A
}

/// Rounded primary button in the user's accent, as on "Done".
struct DeskfocusPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }

    /// A view, so it can read the accent from the environment.
    private struct PrimaryButtonBody: View {
        @Environment(\.deskfocusAccent) private var accent
        let configuration: ButtonStyleConfiguration

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent.onAccent)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(accent.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(configuration.isPressed ? 0.8 : 1)
        }
    }
}

/// Red button for ending a session without finishing the task.
struct DeskfocusDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(DeskfocusTheme.danger.opacity(configuration.isPressed ? 0.7 : 0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
