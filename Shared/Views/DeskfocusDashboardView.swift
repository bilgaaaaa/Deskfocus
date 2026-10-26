import AppIntents
import SwiftUI

/// How much room the dashboard has: compact for the medium widget, expanded for the large widget and desktop panel.
enum DashboardLayout {
    case compact
    case expanded

    var maxRows: Int { self == .expanded ? 7 : 3 }
    var timerFontSize: CGFloat { self == .expanded ? 52 : 36 }
}

/// Today's list, or the focus timer while a session exists; shared by the widget and the glass desktop panel.
struct DeskfocusDashboardView: View {
    let snapshot: DeskfocusSnapshot
    let date: Date
    let layout: DashboardLayout

    var body: some View {
        if let session = snapshot.focus {
            DashboardFocusView(session: session, phase: session.phase(at: date), layout: layout)
        } else {
            DashboardTaskListView(tasks: snapshot.visibleTasks(at: date), now: date, layout: layout)
        }
    }
}

/// Today's list with a play button on every row.
private struct DashboardTaskListView: View {
    let tasks: [DeskTask]
    let now: Date
    let layout: DashboardLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text("\(tasks.count) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if tasks.isEmpty {
                Spacer()
                Text("All clear for today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(tasks.prefix(layout.maxRows)) { task in
                    DashboardTaskRow(task: task, now: now)
                }
                if tasks.count > layout.maxRows {
                    Text("+\(tasks.count - layout.maxRows) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct DashboardTaskRow: View {
    let task: DeskTask
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color(hex: task.colorHex) ?? .accentColor)
                .frame(width: 3, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(DeskTaskFormatter.subtitle(for: task, now: now))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button(intent: StartFocusIntent(taskId: task.id)) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .help("Start focus on this task")
        }
    }
}

/// Live countdown with controls; stays on screen after the timer ends until the task is done or dismissed.
private struct DashboardFocusView: View {
    let session: FocusSession
    let phase: FocusPhase
    let layout: DashboardLayout

    var body: some View {
        VStack(alignment: .leading, spacing: layout == .expanded ? 14 : 8) {
            Label(headline, systemImage: "scope")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(session.taskTitle)
                .font(.headline)
                .lineLimit(2)

            timer

            Spacer(minLength: 0)

            controls
        }
    }

    private var headline: String {
        switch phase {
        case .running: return "Focusing"
        case .paused: return "Paused"
        case .finished: return "Time's up"
        }
    }

    @ViewBuilder
    private var timer: some View {
        switch phase {
        case .running(let endDate):
            Text(timerInterval: Date.now...max(endDate, .now), countsDown: true)
                .font(.system(size: layout.timerFontSize, weight: .semibold, design: .rounded).monospacedDigit())
            ProgressView(timerInterval: session.progressStart(for: endDate)...endDate, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        case .paused(let remaining):
            Text(DeskTaskFormatter.clock(remaining))
                .font(.system(size: layout.timerFontSize, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
        case .finished:
            Text("Nice work. Done, or another round?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            switch phase {
            case .running:
                Button(intent: PauseFocusIntent()) { Label("Pause", systemImage: "pause.fill") }
            case .paused:
                Button(intent: ResumeFocusIntent()) { Label("Resume", systemImage: "play.fill") }
            case .finished:
                Button(intent: StartFocusIntent(taskId: session.taskId)) { Label("Again", systemImage: "arrow.clockwise") }
            }

            Button(intent: CompleteTaskIntent(taskId: session.taskId)) { Label("Done", systemImage: "checkmark") }

            Spacer(minLength: 0)

            Button(intent: StopFocusIntent()) {
                Image(systemName: "xmark")
            }
            .help(phase == .finished ? "Dismiss" : "Stop")
        }
        .font(.caption)
        .buttonStyle(.bordered)
    }
}
