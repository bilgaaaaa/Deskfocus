import AppIntents
import SwiftUI

/// The running session in one line above the week, so it stays in reach while browsing.
struct FocusStrip: View {
    @Environment(\.deskfocusAccent) private var accent
    let session: FocusSession
    let now: Date

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let progress = 1 - session.remaining(at: now) / max(session.plannedDuration, 1)

        HStack(spacing: 12) {
            FocusRingView(progress: progress, lineWidth: 4)
                .frame(width: 30, height: 30)
                .animation(DeskfocusMotion.ringTick, value: progress)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.taskTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(statusLine)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(accent.color)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(DeskfocusMotion.digitRoll, value: statusLine)
            }
            Spacer(minLength: 6)
            controls
        }
        .padding(10)
        .background(accent.color.opacity(0.12), in: shape)
        .overlay(shape.strokeBorder(accent.color.opacity(0.3)))
    }

    private var statusLine: String {
        switch session.phase(at: now) {
        case .running: return String(localized: "\(DeskTaskFormatter.clock(session.remaining(at: now))) left · focusing")
        case .paused(let remaining): return String(localized: "\(DeskTaskFormatter.clock(remaining)) left · paused")
        case .finished: return String(localized: "Time's up")
        }
    }

    /// Pause or resume (another round once the time is up), done, and end; the same intents as the widget.
    private var controls: some View {
        HStack(spacing: 6) {
            switch session.phase(at: now) {
            case .running:
                iconButton("pause.fill", label: "Pause", intent: PauseFocusIntent())
            case .paused:
                iconButton("play.fill", label: "Resume", intent: ResumeFocusIntent())
            case .finished:
                iconButton("arrow.clockwise", label: "Another round", intent: StartFocusIntent(taskId: session.taskId))
            }
            iconButton("checkmark", label: "Done", intent: CompleteTaskIntent(taskId: session.taskId))
            if session.phase(at: now) == .finished {
                iconButton("xmark", label: "Dismiss", intent: EndFocusIntent())
            } else {
                iconButton("stop.fill", label: "End Session", intent: EndFocusIntent(), isDanger: true)
            }
        }
    }

    private func iconButton(_ systemName: String, label: LocalizedStringKey, intent: some AppIntent, isDanger: Bool = false) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isDanger ? Color.white : Color.primary)
                .frame(width: 34, height: 34)
                .background(isDanger ? DeskfocusTheme.danger.opacity(0.9) : Color.white.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(DeskfocusPressStyle())
        .accessibilityLabel(label)
    }
}
