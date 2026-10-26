import Foundation
import Observation

/// Reacts to focus changes from any process: guards distractions while running, ends the timer on time and notifies the user.
@MainActor
@Observable
final class FocusCoordinator {
    private(set) var session: FocusSession?

    private let distractionGuard = DistractionGuard()
    private var endTimer: Timer?

    /// Reads the shared state and brings the guard and end timer in line with it; safe to call any number of times.
    func reconcile(now: Date = .now) {
        if let finished = FocusController.markFinishedIfElapsed(now: now) {
            FocusNotifier.notifyFinished(finished)
        }

        let snapshot = SharedStore.shared.load()
        session = snapshot.focus

        let phase = snapshot.focus?.phase(at: now)
        if case .running(let endDate) = phase {
            if !distractionGuard.isActive {
                distractionGuard.activate(settings: snapshot.settings)
            }
            scheduleEnd(at: endDate)
        } else {
            if distractionGuard.isActive {
                distractionGuard.deactivate()
            }
            cancelEndTimer()
        }
    }

    private func scheduleEnd(at endDate: Date) {
        if let endTimer, endTimer.fireDate == endDate, endTimer.isValid { return }
        cancelEndTimer()

        let timer = Timer(fire: endDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                Log.focus.debug("End timer fired")
                self?.reconcile()
            }
        }
        // Common modes keep the timer firing while menus are open.
        RunLoop.main.add(timer, forMode: .common)
        endTimer = timer
        Log.focus.debug("End timer scheduled")
    }

    private func cancelEndTimer() {
        endTimer?.invalidate()
        endTimer = nil
    }
}
