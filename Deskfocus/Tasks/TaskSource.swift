import Foundation

/// One place tasks come from; the repository merges every available source into today's list.
@MainActor
protocol TaskSource: AnyObject {
    var kind: TaskSourceKind { get }
    /// False when the user has not granted access or connected the account yet.
    var isAvailable: Bool { get }
    func fetchTasks(in day: DateInterval, settings: DeskfocusSettings) async throws -> [DeskTask]
    func complete(_ task: DeskTask) async throws
}

extension DateInterval {
    /// Midnight to midnight of the given day in the current calendar.
    static func day(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }
}

extension DeskTask {
    /// Shared rule for to-dos: show anything due today or overdue, plus undated items when enabled.
    static func isDueForToday(_ dueDate: Date?, day: DateInterval, includeUndated: Bool) -> Bool {
        guard let dueDate else { return includeUndated }
        return dueDate < day.end
    }

    /// Same placeholder for untitled items across every source.
    static func displayTitle(_ rawTitle: String?) -> String {
        let trimmed = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "(No title)" : trimmed
    }
}
