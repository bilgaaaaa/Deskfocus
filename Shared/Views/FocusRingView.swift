import SwiftUI

/// Circular progress in the user's accent gradient, with any content in the middle.
struct FocusRingView<Center: View>: View {
    @Environment(\.deskfocusAccent) private var accent
    let progress: Double
    var lineWidth: CGFloat = 12
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(colors: [accent.colors.light, accent.colors.deep], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            center()
        }
    }
}

extension FocusRingView where Center == EmptyView {
    init(progress: Double, lineWidth: CGFloat = 12) {
        self.init(progress: progress, lineWidth: lineWidth) { EmptyView() }
    }
}
