import AppKit
import SwiftUI

/// Indigo-tinted glass behind the desktop panel: Liquid Glass on macOS 26, a behind-window blur on macOS 14 and 15.
struct DesktopGlassBackground: ViewModifier {
    static let cornerRadius: CGFloat = 26
    private static let tint = DeskfocusTheme.ink.opacity(0.38)
    private let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)

    @ViewBuilder
    func body(content: Content) -> some View {
        // The Liquid Glass API only exists in the macOS 26 SDK (Swift 6.2), so older Xcodes compile the fallback.
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(Self.tint), in: shape)
        } else {
            blurredBackground(content)
        }
        #else
        blurredBackground(content)
        #endif
    }

    private func blurredBackground(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    BehindWindowBlur()
                    Self.tint
                }
                .clipShape(shape)
            }
            .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }
}

/// AppKit blur that samples the wallpaper behind the window.
private struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
