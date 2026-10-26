import SwiftUI

extension GlassTint {
    /// Top-left and bottom-right colors of the tint; the purple pair matches the original widget.
    var colors: (top: Color, bottom: Color) {
        switch self {
        case .purple: return (Self.rgb(0x5B50F0), Self.rgb(0x1C1747))
        case .indigo: return (Self.rgb(0x3F51B5), Self.rgb(0x121A3F))
        case .blue: return (Self.rgb(0x2F80ED), Self.rgb(0x0B2447))
        case .teal: return (Self.rgb(0x1FA2A6), Self.rgb(0x0B3436))
        case .green: return (Self.rgb(0x34A853), Self.rgb(0x10331C))
        case .orange: return (Self.rgb(0xF2994A), Self.rgb(0x4A2209))
        case .rose: return (Self.rgb(0xE0577F), Self.rgb(0x431325))
        case .graphite: return (Self.rgb(0x5A5F6B), Self.rgb(0x1B1D22))
        case .clear: return (Color.white.opacity(0.08), Color.white.opacity(0.02))
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [colors.top, colors.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Color shown in the swatch picker.
    var swatch: Color {
        self == .clear ? Color.white.opacity(0.35) : colors.top
    }

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

/// Row of round color swatches; the selected one gets a ring, like a widget color picker.
struct SwatchPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let color: (Value) -> Color
    let name: (Value) -> String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button { selection = option } label: {
                    Circle()
                        .fill(color(option))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                        .frame(width: 22, height: 22)
                        .padding(3)
                        .overlay(Circle().strokeBorder(Color.primary, lineWidth: selection == option ? 2 : 0))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(name(option))
                .accessibilityLabel(name(option))
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
    }
}
