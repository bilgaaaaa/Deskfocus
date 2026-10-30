import ActivityKit
import Foundation

/// Keeps one Live Activity in step with the focus session: started with it, updated on every change, ended with it.
@MainActor
final class FocusLiveActivity {
    /// Changes from the last update still on their way, so an intent can wait for them before it returns.
    private(set) var pendingUpdate: Task<Void, Never>?

    func update(for session: FocusSession?, settings: DeskfocusSettings, now: Date) {
        let activities = Activity<FocusActivityAttributes>.activities
        let current = activities.first { $0.attributes.sessionId == session?.id }
        let outdated = activities.filter { $0.attributes.sessionId != session?.id }

        // A session already over when the app first sees it gets none; the alert has told the user.
        if let session, current == nil, session.phase(at: now) != .finished {
            start(session, settings: settings, now: now)
        }

        let content = session.map { Self.content(for: $0, now: now) }
        let previous = pendingUpdate
        pendingUpdate = Task {
            await previous?.value
            for activity in outdated {
                await activity.end(nil, dismissalPolicy: .immediate)
                Log.focus.info("Live Activity ended")
            }
            if let current, let content, current.content.state != content.state {
                await current.update(content)
                Log.focus.debug("Live Activity updated")
            }
        }
    }

    private func start(_ session: FocusSession, settings: DeskfocusSettings, now: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.focus.info("Live Activities are turned off for Deskfocus")
            return
        }
        let attributes = FocusActivityAttributes(
            sessionId: session.id,
            taskId: session.taskId,
            taskTitle: session.taskTitle,
            accent: settings.accentColor,
            tint: settings.glassTint
        )
        do {
            _ = try Activity<FocusActivityAttributes>.request(attributes: attributes, content: Self.content(for: session, now: now), pushType: nil)
            Log.focus.info("Live Activity started")
        } catch {
            Log.focus.error("Could not start the Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func content(for session: FocusSession, now: Date) -> ActivityContent<FocusActivityAttributes.ContentState> {
        let state = FocusActivityAttributes.ContentState(session: session, now: now)
        // A running timer turns stale at its end, which the views show as "Time's up" even while the app sleeps.
        var staleDate: Date?
        if case .running(let endDate) = state.phase {
            staleDate = endDate
        }
        return ActivityContent(state: state, staleDate: staleDate)
    }
}
