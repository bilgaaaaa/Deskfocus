import AppKit
import SwiftUI

/// Tinted glass behind the desktop widget: Liquid Glass on macOS 26, a behind-window blur on macOS 14 and 15.
/// `intensity` sets how much color covers the glass: strong when closed (day), light when open (week).
struct DesktopGlassBackground: ViewModifier {
    static let cornerRadius: CGFloat = 26

    let tint: GlassTint
    let intensity: Double

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        let tinted = content.background(tint.gradient.opacity(intensity), in: shape)

        // The Liquid Glass API only exists in the macOS 26 SDK (Swift 6.2), so older Xcodes compile the fallback.
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            tinted.glassEffect(.regular, in: shape)
        } else {
            blurredBackground(tinted)
        }
        #else
        blurredBackground(tinted)
        #endif
    }

    private func blurredBackground(_ content: some View) -> some View {
        content
            .background(BehindWindowBlur().clipShape(shape))
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
