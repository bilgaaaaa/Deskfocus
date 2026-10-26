import SwiftUI

/// One task line: calendar color bar, title, time or list, and caller-supplied actions on either side.
struct DeskTaskRow<Leading: View, Trailing: View>: View {
    let task: DeskTask
    let now: Date
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            leading()

            Capsule()
                .fill(Color(hex: task.colorHex) ?? DeskfocusTheme.indigo)
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .lineLimit(1)
                Text(DeskTaskFormatter.subtitle(for: task, now: now))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            trailing()
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

extension DeskTaskRow where Leading == EmptyView {
    init(task: DeskTask, now: Date, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(task: task, now: now, leading: { EmptyView() }, trailing: trailing)
    }
}

/// Round play symbol used for "start focus" everywhere.
struct PlayGlyph: View {
    var size: CGFloat = 30
    var isProminent = false

    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(isProminent ? AnyShapeStyle(DeskfocusTheme.ink) : AnyShapeStyle(Color.primary))
            .frame(width: size, height: size)
            .background {
                if isProminent {
                    Circle().fill(DeskfocusTheme.focusGradient)
                } else {
                    Circle().fill(Color.primary.opacity(0.1))
                }
            }
            .contentShape(Circle())
    }
}
