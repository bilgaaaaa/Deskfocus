import SwiftUI

/// Shared animation curves, so every Deskfocus surface moves the same way.
enum DeskfocusMotion {
    /// Buttons sinking in under the pointer.
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
    /// Hover highlights fading in and out.
    static let hover = Animation.easeOut(duration: 0.15)
    /// Moving between days and weeks.
    static let navigate = Animation.snappy(duration: 0.32)
    /// Rows arriving, leaving and closing the gap.
    static let list = Animation.spring(response: 0.4, dampingFraction: 0.85)
    /// Swapping between the agenda and the focus session, and between session phases.
    static let reveal = Animation.spring(response: 0.5, dampingFraction: 0.82)
    /// One step of a running ring; as long as the panel's one-second tick, so the arc never stops.
    static let ringTick = Animation.linear(duration: 1)
    /// Digits rolling to their next value.
    static let digitRoll = Animation.snappy(duration: 0.35)
    /// Half a breath of the glow behind the ring while focusing.
    static let breathe = Animation.easeInOut(duration: 2.4)
    /// How long the tick stays on a checked item before its row leaves.
    static let completionDelay: Duration = .milliseconds(380)
}

private struct DeskfocusAmbientMotionKey: EnvironmentKey {
    static let defaultValue = false
}

private struct DeskfocusRowHoveredKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True on live surfaces such as the desktop panel, where looping animations run; WidgetKit only draws still frames.
    var deskfocusAmbientMotion: Bool {
        get { self[DeskfocusAmbientMotionKey.self] }
        set { self[DeskfocusAmbientMotionKey.self] = newValue }
    }

    /// True while the pointer is over the row holding this view, so its ▶ and ✓ can light up.
    var deskfocusRowHovered: Bool {
        get { self[DeskfocusRowHoveredKey.self] }
        set { self[DeskfocusRowHoveredKey.self] = newValue }
    }
}

/// Soft highlight behind a row while the pointer is over it; does nothing in WidgetKit, which has no pointer.
private struct DeskfocusHoverHighlight: ViewModifier {
    let cornerRadius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .environment(\.deskfocusRowHovered, isHovered)
            .background(Color.white.opacity(isHovered ? 0.08 : 0), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onHover { hovering in
                withAnimation(DeskfocusMotion.hover) { isHovered = hovering }
            }
    }
}

extension View {
    /// Lights up the row under the pointer and tells its buttons through `deskfocusRowHovered`.
    func deskfocusHoverHighlight(cornerRadius: CGFloat = 12) -> some View {
        modifier(DeskfocusHoverHighlight(cornerRadius: cornerRadius))
    }
}
