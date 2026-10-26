import AppIntents
import SwiftUI

/// How much room the widget has: compact for the medium widget, expanded for the large one.
enum DashboardLayout {
    case compact
    case expanded

    var maxRows: Int { self == .expanded ? 4 : 0 }
}

/// Today's list, or the focus session while one exists; the WidgetKit widget's content.
struct DeskfocusDashboardView: View {
    let snapshot: DeskfocusSnapshot
    let date: Date
    let layout: DashboardLayout

    var body: some View {
        if let session = snapshot.focus {
            FocusSessionView(
                session: session,
                now: date,
                settings: snapshot.settings,
                size: layout == .expanded ? .regular : .compact
            )
        } else {
            let tasks = snapshot.visibleTasks(at: date)
            let done = snapshot.completedCount(on: date)
            VStack(alignment: .leading, spacing: 10) {
                DayHeaderView(date: date) {
                    DayProgressRing(done: done, total: done + tasks.count)
                }
                DayAgendaView(
                    tasks: tasks,
                    now: date,
                    maxRows: layout.maxRows,
                    showsUpNext: true,
                    savedProgress: snapshot.savedProgress,
                    rowAction: { task in
                        Button(intent: StartFocusIntent(taskId: task.id)) { PlayGlyph(size: 26) }
                            .buttonStyle(.plain)
                    },
                    upNextAction: { task in
                        Button(intent: StartFocusIntent(taskId: task.id)) { PlayGlyph(size: 38, isProminent: true) }
                            .buttonStyle(.plain)
                    }
                )
                Spacer(minLength: 0)
            }
        }
    }
}
