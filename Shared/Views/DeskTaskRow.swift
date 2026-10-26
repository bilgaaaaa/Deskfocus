import SwiftUI

/// One task line: calendar color bar, title, time or list, and caller-supplied actions on either side.
struct DeskTaskRow<Leading: View, Trailing: View>: View {
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
                TaskSubtitleLine(task: task, now: now, resumeRemaining: resumeRemaining)
                    .font(.system(size: 11))
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

/// "12:30 left · 10:00 – 11:00 · Work" under a title; overdue to-dos turn red so they stand out.
struct TaskSubtitleLine: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    let task: DeskTask
    let now: Date
    var resumeRemaining: TimeInterval? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let resumeRemaining {
                Label(DeskTaskFormatter.timeLeft(resumeRemaining), systemImage: "pause.circle.fill")
                    .foregroundStyle(accent.color)
                Text(verbatim: "·")
                    .foregroundStyle(.secondary)
            }
            Text(DeskTaskFormatter.subtitle(for: task, now: now))
                .foregroundStyle(task.isOverdue(at: now) ? AnyShapeStyle(DeskfocusTheme.overdue(in: colorScheme)) : AnyShapeStyle(.secondary))
        }
        .lineLimit(1)
    }
}

/// Round play symbol used for "start focus" everywhere; it takes the accent when prominent or when its row is hovered.
struct PlayGlyph: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(\.deskfocusRowHovered) private var isRowHovered
    var size: CGFloat = 30
    var isProminent = false

    private var showsAccent: Bool { isProminent || isRowHovered }

    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.36, weight: .bold))
            // The triangle's visual center sits left of its box, so nudge it right.
            .offset(x: size * 0.03)
            .foregroundStyle(showsAccent ? accent.onAccent : Color.primary)
            .frame(width: size, height: size)
            .background {
                Circle().fill(Color.primary.opacity(0.1))
                Circle().fill(accent.gradient).opacity(showsAccent ? 1 : 0)
            }
            .shadow(color: accent.colors.deep.opacity(isProminent ? 0.45 : 0), radius: size * 0.22, y: size * 0.08)
            .contentShape(Circle())
    }
}

/// Round checkbox for "mark as done": checking fills it with the accent and traces the tick,
/// previewing (pointer on the box) shows a faint tick first.
struct CheckGlyph: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(\.deskfocusRowHovered) private var isRowHovered
    var size: CGFloat = 20
    var isChecked = false
    var isPreviewing = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.primary.opacity(isRowHovered || isPreviewing ? 0.75 : 0.4), lineWidth: 1.5)
                .opacity(isChecked ? 0 : 1)
            Circle()
                .fill(accent.gradient)
                .scaleEffect(isChecked ? 1 : 0.3)
                .opacity(isChecked ? 1 : 0)
            CheckmarkShape()
                .trim(from: 0, to: isChecked || isPreviewing ? 1 : 0)
                .stroke(
                    isChecked ? accent.onAccent : Color.primary.opacity(0.55),
                    style: StrokeStyle(lineWidth: max(1.5, size * 0.1), lineCap: .round, lineJoin: .round)
                )
                .padding(size * 0.29)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}

/// The tick inside `CheckGlyph`, one open stroke so it can be traced on with `trim`.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return path
    }
}
