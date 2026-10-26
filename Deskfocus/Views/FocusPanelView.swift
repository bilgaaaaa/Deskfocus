import SwiftUI

/// The running, paused or finished focus session with its controls.
struct FocusPanelView: View {
    @Environment(AppModel.self) private var model
    let session: FocusSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 12) {
                Label(headline(for: session.phase(at: context.date)), systemImage: "scope")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(session.taskTitle)
                    .font(.headline)
                    .lineLimit(2)

                timer(for: session.phase(at: context.date), now: context.date)

                controls(for: session.phase(at: context.date))
            }
        }
    }

    @ViewBuilder
    private func timer(for phase: FocusPhase, now: Date) -> some View {
        switch phase {
        case .running(let endDate):
            Text(DeskTaskFormatter.clock(endDate.timeIntervalSince(now)))
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
            ProgressView(value: progress(remaining: endDate.timeIntervalSince(now)))
        case .paused(let remaining):
            Text(DeskTaskFormatter.clock(remaining))
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
            ProgressView(value: progress(remaining: remaining))
        case .finished:
            Text("Time's up")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
        }
    }

    @ViewBuilder
    private func controls(for phase: FocusPhase) -> some View {
        HStack {
            switch phase {
            case .running:
                Button("Pause", systemImage: "pause.fill") { model.pauseFocus() }
            case .paused:
                Button("Resume", systemImage: "play.fill") { model.resumeFocus() }
            case .finished:
                EmptyView()
            }

            Button("Done", systemImage: "checkmark") { model.complete(taskId: session.taskId) }
                .keyboardShortcut(.defaultAction)

            Spacer()

            Button(phase == .finished ? "Dismiss" : "Stop", role: .cancel) { model.stopFocus() }
        }
        .controlSize(.regular)
    }

    private func headline(for phase: FocusPhase) -> String {
        switch phase {
        case .running: return "Focusing"
        case .paused: return "Paused"
        case .finished: return "Session complete"
        }
    }

    private func progress(remaining: TimeInterval) -> Double {
        guard session.plannedDuration > 0 else { return 0 }
        return min(max(1 - remaining / session.plannedDuration, 0), 1)
    }
}
