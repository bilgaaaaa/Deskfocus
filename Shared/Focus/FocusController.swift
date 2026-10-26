import Foundation
import WidgetKit

/// All focus and completion state changes go through here, from the app, the widget buttons or Shortcuts.
enum FocusController {
    /// Sessions with less time left than this are not worth resuming later.
    private static let minimumResumableTime: TimeInterval = 30

    /// Starts or resumes focus on a task; `minutes` overrides the task's own length and is remembered for it.
    /// Returns nil if the task is unknown.
    @discardableResult
    static func start(taskId: String, minutes: Int? = nil, now: Date = .now) -> FocusSession? {
        var started: FocusSession?
        SharedStore.shared.update { snapshot in
            guard let task = snapshot.task(withId: taskId) else {
                Log.focus.error("Start ignored, unknown task \(taskId, privacy: .public)")
                return
            }

            // ▶ on the task that is already paused simply resumes it.
            if minutes == nil, var current = snapshot.focus, current.taskId == task.id,
               case .paused(let remaining) = current.phase(at: now) {
                current.status = .running(endDate: now.addingTimeInterval(remaining))
                snapshot.focus = current
                started = current
                return
            }

            saveProgressOfCurrentSession(in: &snapshot, now: now)
            if let minutes {
                snapshot.rememberFocusMinutes(minutes, for: task.id, now: now)
                snapshot.savedProgress[task.id] = nil
            }

            let time = focusTime(for: task, in: snapshot, now: now)
            snapshot.savedProgress[task.id] = nil
            let session = FocusSession(
                id: UUID(),
                taskId: task.id,
                taskTitle: task.title,
                startedAt: now,
                plannedDuration: time.planned,
                status: .running(endDate: now.addingTimeInterval(time.remaining))
            )
            snapshot.focus = session
            started = session
        }
        if let started {
            Log.focus.info("Focus started, \(Int(started.remaining(at: now) / 60)) of \(Int(started.plannedDuration / 60)) min")
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

    /// Ends focus on a task without completing it and forgets its time left; nil means the current session.
    static func end(taskId: String? = nil) {
        SharedStore.shared.update { snapshot in
            guard let taskId = taskId ?? snapshot.focus?.taskId else { return }
            if snapshot.focus?.taskId == taskId {
                snapshot.focus = nil
            }
            snapshot.savedProgress[taskId] = nil
            Log.focus.info("Focus session ended")
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
            snapshot.savedProgress[task.id] = nil
            snapshot.forgetFocusMinutes(for: task.id)
            Log.focus.info("Task completed from \(task.source.rawValue, privacy: .public)")
        }
        notifyChange()
    }

    /// Tells the other process and WidgetKit that the shared state changed.
    static func notifyChange() {
        DarwinNotifier.post(DeskfocusConstants.stateChangedNotification)
        WidgetCenter.shared.reloadTimelines(ofKind: DeskfocusConstants.widgetKind)
    }

    // MARK: Focus time

    /// How long to focus, in order: saved progress, the minutes chosen for this task,
    /// the event's own length (or what is left of it), then the default from Settings.
    static func focusTime(for task: DeskTask, in snapshot: DeskfocusSnapshot, now: Date) -> (remaining: TimeInterval, planned: TimeInterval) {
        if let saved = snapshot.savedProgress[task.id] {
            return (saved.remaining, saved.planned)
        }
        if let minutes = snapshot.taskFocusMinutes[task.id] {
            let duration = DeskfocusSettings.clampedDuration(minutes: minutes)
            return (duration, duration)
        }
        if task.isEvent, !task.isAllDay, let start = task.startDate, let end = task.endDate, end > start {
            // Already happening: focus until the event ends.
            let reference = start <= now && now < end ? now : start
            let duration = DeskfocusSettings.clampedDuration(minutes: Int((end.timeIntervalSince(reference) / 60).rounded()))
            return (duration, duration)
        }
        let duration = snapshot.settings.focusDuration
        return (duration, duration)
    }

    /// Keeps the time left on the current session so its task can be resumed later.
    private static func saveProgressOfCurrentSession(in snapshot: inout DeskfocusSnapshot, now: Date) {
        guard let current = snapshot.focus else { return }
        let remaining = current.remaining(at: now)
        guard current.phase(at: now) != .finished, remaining >= minimumResumableTime else { return }
        snapshot.savedProgress[current.taskId] = SavedFocusProgress(remaining: remaining, planned: current.plannedDuration, savedAt: now)
        Log.focus.info("Saved \(Int(remaining / 60)) min to resume later")
    }
}
