import SwiftUI

/// Big weekday + date header with any trailing control (progress ring, day arrows).
struct DayHeaderView<Trailing: View>: View {
    @Environment(\.deskfocusAccent) private var accent
    let date: Date
    /// Which way the date rolls when it changes inside an animation.
    var movesForward = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DeskTaskFormatter.weekday(date).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(accent.color)
                Text(DeskTaskFormatter.dayMonth(date))
                    .font(.system(size: 26, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .contentTransition(.numericText(countsDown: !movesForward))
            Spacer(minLength: 8)
            trailing()
        }
    }
}

/// Small "2/6" ring showing how much of today is done; it turns into a tick once everything is.
struct DayProgressRing: View {
    @Environment(\.deskfocusAccent) private var accent
    let done: Int
    let total: Int

    private var isComplete: Bool { total > 0 && done == total }

    var body: some View {
        FocusRingView(progress: total > 0 ? Double(done) / Double(total) : 0, lineWidth: 4.5) {
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(accent.color)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                Text("\(done)/\(total)")
                    .font(.system(size: 10.5, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(done)))
                    .transition(.opacity)
            }
        }
        .frame(width: 42, height: 42)
        .animation(DeskfocusMotion.reveal, value: done)
        .animation(DeskfocusMotion.reveal, value: total)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) done")
    }
}

/// A day's list: optional "Up next" card for the first item, then the rest as rows.
/// Rows slide in as items arrive and slide out to the right when checked off.
struct DayAgendaView<CompleteAction: View, RowAction: View, UpNextAction: View>: View {
    @Environment(\.deskfocusAccent) private var accent
    let tasks: [DeskTask]
    let now: Date
    let maxRows: Int
    let showsUpNext: Bool
    /// Unfinished sessions by task id, shown as "12:30 left" on their rows.
    var savedProgress: [String: SavedFocusProgress] = [:]
    /// The checkbox in front of every item, the "Up next" card's included.
    @ViewBuilder var completeAction: (DeskTask) -> CompleteAction
    @ViewBuilder var rowAction: (DeskTask) -> RowAction
    @ViewBuilder var upNextAction: (DeskTask) -> UpNextAction

    private static var rowTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: .trailing))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tasks.isEmpty {
                emptyState
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                if showsUpNext, let next = tasks.first {
                    UpNextCard(task: next, now: now, resumeRemaining: savedProgress[next.id]?.remaining) {
                        completeAction(next)
                    } action: {
                        upNextAction(next)
                    }
                    .id(next.id)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
                }
                let rows = Array(tasks.dropFirst(showsUpNext ? 1 : 0))
                VStack(spacing: 2) {
                    ForEach(rows.prefix(maxRows)) { task in
                        DeskTaskRow(task: task, now: now, resumeRemaining: savedProgress[task.id]?.remaining) {
                            completeAction(task)
                        } trailing: {
                            rowAction(task)
                        }
                        .padding(.horizontal, 8)
                        .deskfocusHoverHighlight()
                        .transition(Self.rowTransition)
                    }
                }
                if rows.count > maxRows {
                    Text("+\(rows.count - maxRows) more")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 8)
                }
            }
        }
        .animation(DeskfocusMotion.list, value: tasks.map(\.id))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(accent.gradient)
            Text("All clear")
                .font(.system(size: 14, weight: .semibold))
            Text("Nothing planned for this day.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

/// The first item of today, larger; its status line says when it starts and shows a live bar while an event is under way.
private struct UpNextCard<Complete: View, Action: View>: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(\.deskfocusAmbientMotion) private var ambientMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let task: DeskTask
    let now: Date
    var resumeRemaining: TimeInterval? = nil
    @ViewBuilder var complete: () -> Complete
    @ViewBuilder var action: () -> Action

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            statusLine
            HStack(spacing: 10) {
                complete()
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .lineLimit(2)
                    TaskSubtitleLine(task: task, now: now, resumeRemaining: resumeRemaining)
                        .font(.system(size: 11.5))
                }
                Spacer(minLength: 6)
                action()
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.1), in: shape)
        .overlay(shape.strokeBorder(DeskfocusTheme.glassStroke))
    }

    private var statusLine: some View {
        let label = DeskTaskFormatter.upNextLabel(for: task, now: now)
        return HStack(spacing: 6) {
            statusIcon
            Text(label)
                .contentTransition(.numericText(countsDown: true))
            if let progress = task.eventProgress(at: now) {
                Spacer(minLength: 8)
                EventProgressBar(progress: progress)
                    .frame(width: 64)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(statusColor)
        .lineLimit(1)
        .animation(DeskfocusMotion.digitRoll, value: label)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if task.isHappening(at: now) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: ambientMotion && !reduceMotion)
        } else if task.isOverdue(at: now) {
            Image(systemName: "exclamationmark.circle.fill")
        } else if task.isEvent, !task.isAllDay {
            Image(systemName: "clock")
        } else {
            Image(systemName: "checklist")
        }
    }

    private var statusColor: Color {
        if task.isHappening(at: now) { return accent.color }
        if task.isOverdue(at: now) { return DeskfocusTheme.overdue(in: colorScheme) }
        return .secondary
    }
}

/// Thin bar for how much of a happening event has passed.
private struct EventProgressBar: View {
    @Environment(\.deskfocusAccent) private var accent
    let progress: Double

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.16))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(accent.gradient)
                        .frame(width: max(proxy.size.height, proxy.size.width * min(max(progress, 0), 1)))
                }
            }
            .frame(height: 4)
            .animation(DeskfocusMotion.reveal, value: progress)
            .accessibilityHidden(true)
    }
}
