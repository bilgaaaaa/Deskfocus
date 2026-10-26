import Foundation
import WidgetKit

/// All focus and completion state changes go through here, from the app, the widget buttons or Shortcuts.
enum FocusController {
    /// Starts a timer for the task, replacing any current session; returns nil if the task is unknown.
    @discardableResult
    static func start(taskId: String, now: Date = .now) -> FocusSession? {
        var started: FocusSession?
        SharedStore.shared.update { snapshot in
            guard let task = snapshot.task(withId: taskId) else {
                Log.focus.error("Start ignored, unknown task \(taskId, privacy: .public)")
                return
            }
            if let current = snapshot.focus {
                Log.focus.info("Replacing session for \(current.taskTitle, privacy: .private)")
            }
            let duration = snapshot.settings.focusDuration
            let session = FocusSession(
                id: UUID(),
                taskId: task.id,
                taskTitle: task.title,
                startedAt: now,
                plannedDuration: duration,
                status: .running(endDate: now.addingTimeInterval(duration))
            )
            snapshot.focus = session
            started = session
        }
        if let started {
            Log.focus.info("Focus started for \(Int(started.plannedDuration / 60)) min")
        }
        notifyChange()
        return started
    }

    static func pause(now: Date = .now) {
        SharedStore.shared.update { snapshot in
            guard var session = snapshot.focus, case .running(let endDate) = session.phase(at: now) else {
                Log.focus.debug("Pause ignored, no running session")
                return
            }
            session.status = .paused(remaining: endDate.timeIntervalSince(now))
            snapshot.focus = session
            Log.focus.info("Focus paused")
        }
        notifyChange()
    }

    static func resume(now: Date = .now) {
        SharedStore.shared.update { snapshot in
            guard var session = snapshot.focus, case .paused(let remaining) = session.phase(at: now) else {
                Log.focus.debug("Resume ignored, no paused session")
                return
            }
            session.status = .running(endDate: now.addingTimeInterval(remaining))
            snapshot.focus = session
            Log.focus.info("Focus resumed")
        }
        notifyChange()
    }

    /// Ends the session without completing the task.
    static func stop() {
        SharedStore.shared.update { snapshot in
            guard snapshot.focus != nil else { return }
            snapshot.focus = nil
            Log.focus.info("Focus stopped")
        }
        notifyChange()
    }

    /// Records a running session that reached its end; returns it so the caller can notify the user once.
    @discardableResult
    static func markFinishedIfElapsed(now: Date = .now) -> FocusSession? {
        var finished: FocusSession?
        SharedStore.shared.update { snapshot in
            guard var session = snapshot.focus,
                  case .running = session.status,
                  session.phase(at: now) == .finished else { return }
            session.status = .finished
            snapshot.focus = session
            finished = session
        }
        if finished != nil {
            Log.focus.info("Focus time is up")
            notifyChange()
        }
        return finished
    }

    /// Checks a task off; to-dos are queued so the app completes them in their source.
    static func complete(taskId: String, now: Date = .now) {
        SharedStore.shared.update { snapshot in
            guard let task = snapshot.task(withId: taskId) else {
                Log.focus.error("Complete ignored, unknown task \(taskId, privacy: .public)")
                return
            }
            snapshot.completedTaskIds.insert(task.id)
            // Only today's items feed the "done today" ring.
            if snapshot.tasks.contains(where: { $0.id == task.id }) {
                snapshot.completionDates[task.id] = now
            }
            if !task.isEvent {
                snapshot.pendingCompletionIds.insert(task.id)
            }
            if snapshot.focus?.taskId == task.id {
                snapshot.focus = nil
            }
            Log.focus.info("Task completed from \(task.source.rawValue, privacy: .public)")
        }
        notifyChange()
    }

    /// Tells the other process and WidgetKit that the shared state changed.
    static func notifyChange() {
        DarwinNotifier.post(DeskfocusConstants.stateChangedNotification)
        WidgetCenter.shared.reloadTimelines(ofKind: DeskfocusConstants.widgetKind)
    }
}
