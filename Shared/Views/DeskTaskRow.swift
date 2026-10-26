import SwiftUI

/// One task line: calendar color bar, title, time or list, and caller-supplied actions on either side.
struct DeskTaskRow<Leading: View, Trailing: View>: View {
    @Environment(\.deskfocusAccent) private var accent
    let task: DeskTask
    let now: Date
    /// Time left from an earlier, unfinished session.
    var resumeRemaining: TimeInterval? = nil
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
                HStack(spacing: 4) {
                    if let resumeRemaining {
                        Label(DeskTaskFormatter.timeLeft(resumeRemaining), systemImage: "pause.circle.fill")
                            .foregroundStyle(accent.color)
                        Text(verbatim: "·")
                            .foregroundStyle(.secondary)
                    }
                    Text(DeskTaskFormatter.subtitle(for: task, now: now))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 11))
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
    init(task: DeskTask, now: Date, resumeRemaining: TimeInterval? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(task: task, now: now, resumeRemaining: resumeRemaining, leading: { EmptyView() }, trailing: trailing)
    }
}

/// Round play symbol used for "start focus" everywhere.
struct PlayGlyph: View {
    @Environment(\.deskfocusAccent) private var accent
    var size: CGFloat = 30
    var isProminent = false

    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(isProminent ? accent.onAccent : Color.primary)
            .frame(width: size, height: size)
            .background {
                if isProminent {
                    Circle().fill(accent.gradient)
                } else {
                    Circle().fill(Color.primary.opacity(0.1))
                }
            }
            .contentShape(Circle())
    }
}
