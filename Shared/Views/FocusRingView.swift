import SwiftUI

/// Circular progress in the user's accent gradient, with any content in the middle.
/// Large rings can add a soft glow (breathing on live surfaces) and a knob riding the tip of the arc.
/// Callers animate it with `.animation(_:value:)` on the progress, since a ticking timer and a day count want different curves.
struct FocusRingView<Center: View>: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(\.deskfocusAmbientMotion) private var ambientMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double
    var lineWidth: CGFloat = 12
    var glows = false
    var breathes = false
    var showsKnob = false
    @ViewBuilder var center: () -> Center

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: lineWidth)
            if glows {
                glow
            }
            arc
            if showsKnob, clampedProgress > 0, clampedProgress < 1 {
                knob
                    .transition(.opacity)
            }
            center()
        }
    }

    private var arc: some View {
        Circle()
            .trim(from: 0, to: clampedProgress)
            .stroke(
                AngularGradient(colors: [accent.colors.light, accent.colors.deep], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(clampedProgress, 0.01))),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }

    /// A blurred copy of the arc; it slowly brightens and dims while `breathes`, unless Reduce Motion is on.
    @ViewBuilder
    private var glow: some View {
        if breathes && ambientMotion && !reduceMotion {
            PhaseAnimator([false, true]) { isBright in
                arc
                    .blur(radius: lineWidth * 0.8)
                    .opacity(isBright ? 0.8 : 0.3)
            } animation: { _ in
                DeskfocusMotion.breathe
            }
        } else {
            arc
                .blur(radius: lineWidth * 0.8)
                .opacity(0.45)
        }
    }

    /// White dot on the end of the arc, rotated with the progress so it moves in step with the trim.
    private var knob: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            Circle()
                .fill(Color.white)
                .frame(width: lineWidth * 0.46, height: lineWidth * 0.46)
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 0.5)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2 - radius)
                .rotationEffect(.degrees(360 * clampedProgress))
        }
        .allowsHitTesting(false)
    }
}

extension FocusRingView where Center == EmptyView {
    init(progress: Double, lineWidth: CGFloat = 12) {
        self.init(progress: progress, lineWidth: lineWidth) { EmptyView() }
    }
}
