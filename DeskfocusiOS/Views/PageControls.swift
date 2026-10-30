import SwiftUI

/// ‹ › for the day or the week page, large enough for a thumb; the arrows animate the move.
struct PageNavigation: View {
    let previousLabel: LocalizedStringKey
    let nextLabel: LocalizedStringKey
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            PageIconButton(systemName: "chevron.left", label: previousLabel) {
                withAnimation(DeskfocusMotion.navigate, onPrevious)
            }
            PageIconButton(systemName: "chevron.right", label: nextLabel) {
                withAnimation(DeskfocusMotion.navigate, onNext)
            }
        }
        .fixedSize()
    }
}

/// Round icon button in a page header, the touch-sized twin of the Mac panel's buttons.
private struct PageIconButton: View {
    let systemName: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(DeskfocusPressStyle())
        .accessibilityLabel(label)
    }
}

/// Mask that fades the bottom of a list, so rows slip under the page's edge instead of being cut off.
struct BottomFade: View {
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: height)
        }
    }
}
