import Foundation

/// What a focus session is doing at a given moment, derived from its stored status and the clock.
enum FocusPhase: Equatable {
    case running(endDate: Date)
    case paused(remaining: TimeInterval)
    case finished
}

/// A focus timer attached to one task, stored in the shared state so the app and widget see the same session.
struct FocusSession: Codable, Equatable, Identifiable {
    enum Status: Codable, Equatable {
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
        case finished
    }

    let id: UUID
    let taskId: String
    let taskTitle: String
    let startedAt: Date
    /// Grows when the user adds time with "+5 min".
    var plannedDuration: TimeInterval
    var status: Status

    /// A running session whose end date has passed counts as finished even before the app records it.
    func phase(at now: Date) -> FocusPhase {
        switch status {
        case .running(let endDate):
            return endDate > now ? .running(endDate: endDate) : .finished
        case .paused(let remaining):
            return .paused(remaining: remaining)
        case .finished:
            return .finished
        }
    }

    func remaining(at now: Date) -> TimeInterval {
        switch phase(at: now) {
        case .running(let endDate): return max(0, endDate.timeIntervalSince(now))
        case .paused(let remaining): return remaining
        case .finished: return 0
        }
    }

    /// Start of the countdown range, shifted so progress bars stay correct after pause and resume.
    func progressStart(for endDate: Date) -> Date {
        endDate.addingTimeInterval(-plannedDuration)
    }
}
