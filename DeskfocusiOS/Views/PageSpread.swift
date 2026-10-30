import SwiftUI

/// The day and the week as two facing pages, split at the middle of the window. On the open iPhone Duo the middle is the fold,
/// so the gap between the pages lands on it and nothing you tap sits on the crease. Wider than tall the pages sit
/// side by side; taller than wide (the open iPhone Duo held sideways, an iPad upright) one sits above the other.
struct PageSpread: View {
    let now: Date

    /// Gap between the pages, centered on the fold.
    private static let gutter: CGFloat = 28
    /// Room between the pages and the window's outer edges.
    private static let margin: CGFloat = 16

    var body: some View {
        // Measured edge to edge, so the split follows the window's middle even when bars inset one side only.
        GeometryReader { proxy in
            let size = proxy.size
            let insets = proxy.safeAreaInsets

            if size.width >= size.height {
                let fold = size.width / 2
                HStack(spacing: Self.gutter) {
                    DayPage(now: now)
                        .modifier(SpreadPage())
                        .frame(width: max(0, fold - Self.gutter / 2 - insets.leading - Self.margin))
                    WeekPage(now: now)
                        .modifier(SpreadPage())
                        .frame(width: max(0, size.width - fold - Self.gutter / 2 - insets.trailing - Self.margin))
                }
                .padding(.leading, insets.leading + Self.margin)
                .padding(.trailing, insets.trailing + Self.margin)
                .padding(.top, insets.top)
                .padding(.bottom, insets.bottom + Self.margin)
            } else {
                let fold = size.height / 2
                VStack(spacing: Self.gutter) {
                    DayPage(now: now)
                        .modifier(SpreadPage())
                        .frame(height: max(0, fold - Self.gutter / 2 - insets.top))
                    WeekPage(now: now)
                        .modifier(SpreadPage())
                        .frame(height: max(0, size.height - fold - Self.gutter / 2 - insets.bottom - Self.margin))
                }
                .padding(.leading, insets.leading + Self.margin)
                .padding(.trailing, insets.trailing + Self.margin)
                .padding(.top, insets.top)
                .padding(.bottom, insets.bottom + Self.margin)
            }
        }
        .ignoresSafeArea()
    }
}

/// One page of the spread: a glass card like the Mac widget, its content clipped to the rounded corners.
private struct SpreadPage: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        content
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.06), in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(DeskfocusTheme.glassStroke))
    }
}
