import SwiftUI

/// Pulsing placeholder lines while a week loads, instead of a misleading "All clear" or "Free".
struct LoadingPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var lineCount = 3
    var lineHeight: CGFloat = 10

    var body: some View {
        Group {
            if reduceMotion {
                lines(isDim: false)
            } else {
                PhaseAnimator([false, true]) { isDim in
                    lines(isDim: isDim)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    /// Ragged right edges, like real titles of different lengths.
    private func lines(isDim: Bool) -> some View {
        VStack(alignment: .leading, spacing: lineHeight) {
            ForEach(0..<lineCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(isDim ? 0.06 : 0.14))
                    .frame(height: lineHeight)
                    .padding(.trailing, CGFloat(index % 3) * 18)
            }
        }
    }
}
