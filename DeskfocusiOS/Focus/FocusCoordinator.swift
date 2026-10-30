import Foundation
import Observation

/// Reacts to focus changes from any process: schedules the "time is up" alert, keeps the Live Activity in step
/// and records the end on time while the app is open. The iPhone counterpart of the Mac's coordinator, which also hides apps.
@MainActor
@Observable
final class FocusCoordinator {
    private(set) var session: FocusSession?

    private let liveActivity = FocusLiveActivity()
    @ObservationIgnored private var endTimer: Timer?
    /// Session and end the alert is scheduled for, so repeated calls leave it alone.
    @ObservationIgnored private var scheduledFinish: (sessionId: UUID, endDate: Date)?

    /// Reads the shared state and brings the alert, the Live Activity and the end timer in line with it; safe to call any number of times.
    func reconcile(now: Date = .now) {
        // The alert was scheduled ahead, so the end only needs recording here.
        FocusController.markFinishedIfElapsed(now: now)

        let snapshot = SharedStore.shared.load()
        session = snapshot.focus

        switch snapshot.focus?.phase(at: now) {
        case .running(let endDate):
            if let session = snapshot.focus {
                scheduleFinishAlert(for: session, at: endDate, now: now)
            }
            scheduleEnd(at: endDate)
        case .finished:
            // The alert is due right now or already shown; withdrawing it here could silence it.
            scheduledFinish = nil
            cancelEndTimer()
        case .paused, nil:
            // Also withdraws an alert scheduled by an earlier launch of the app.
            FocusNotifier.cancelScheduledFinish()
            scheduledFinish = nil
            cancelEndTimer()
        }
        liveActivity.update(for: snapshot.focus, settings: snapshot.settings, now: now)
    }

    /// Waits for the Live Activity changes started by the last `reconcile`, so a button's intent can finish them before returning.
    func waitForLiveActivity() async {
        await liveActivity.pendingUpdate?.value
    }

    private func scheduleFinishAlert(for session: FocusSession, at endDate: Date, now: Date) {
        if let scheduledFinish, scheduledFinish.sessionId == session.id, scheduledFinish.endDate == endDate { return }
        FocusNotifier.scheduleFinished(session, at: endDate, now: now)
        scheduledFinish = (session.id, endDate)
    }

    /// Flips the session to "time's up" while the app is open; when it is not, the next launch or button does it.
    private func scheduleEnd(at endDate: Date) {
        if let endTimer, endTimer.fireDate == endDate, endTimer.isValid { return }
        cancelEndTimer()

        let timer = Timer(fire: endDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                Log.focus.debug("End timer fired")
                self?.reconcile()
            }
        }
        // Common modes keep the timer firing while the user scrolls.
        RunLoop.main.add(timer, forMode: .common)
        endTimer = timer
        Log.focus.debug("End timer scheduled")
    }

    private func cancelEndTimer() {
        endTimer?.invalidate()
        endTimer = nil
    }
}
