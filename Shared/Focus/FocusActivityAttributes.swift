#if os(iOS)
import ActivityKit
import Foundation

/// The focus session as an iPhone Live Activity: the fixed details here, the changing part in `ContentState`.
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: FocusPhase
        /// Grows with "+5 min", like `FocusSession.plannedDuration`.
        var plannedDuration: TimeInterval
    }

    let sessionId: UUID
    let taskId: String
    let taskTitle: String
    /// Colors picked in Settings when the session started.
    let accent: AccentChoice
    let tint: GlassTint
}

extension FocusActivityAttributes.ContentState {
    init(session: FocusSession, now: Date) {
        self.init(phase: session.phase(at: now), plannedDuration: session.plannedDuration)
    }

    /// Start of the countdown, so the ring and digits can run on their own between updates; see `FocusSession.progressStart`.
    func progressStart(for endDate: Date) -> Date {
        endDate.addingTimeInterval(-plannedDuration)
    }
}
#endif
