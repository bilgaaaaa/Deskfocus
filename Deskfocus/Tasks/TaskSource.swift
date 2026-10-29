import Foundation

/// One place tasks come from; the repository merges every available source.
@MainActor
protocol TaskSource: AnyObject {
    var kind: TaskSourceKind { get }
    /// False when the user has not granted access or connected the account yet.
    var isAvailable: Bool { get }
    /// Every calendar or list the source offers, including the ones switched off in Settings.
    func containers() async throws -> [TaskContainer]
    /// Events overlapping the interval and to-dos due in it; when it includes today, also overdue and undated to-dos.
    /// Calendars and lists switched off in Settings are skipped.
    func fetchTasks(in interval: DateInterval, settings: DeskfocusSettings) async throws -> [DeskTask]
    func complete(_ task: DeskTask) async throws
}

extension DeskTask {
    /// Shared to-do rule for every source, matching how `Agenda` places to-dos on days.
    static func isDue(_ dueDate: Date?, in interval: DateInterval, includeUndated: Bool, now: Date = .now) -> Bool {
        let today = DateInterval.day(containing: now)
        let includesToday = interval.start <= today.start && today.start < interval.end
        guard let dueDate else { return includeUndated && includesToday }
        if dueDate >= interval.start && dueDate < interval.end { return true }
        return includesToday && dueDate < today.start
    }

    /// Same placeholder for untitled items across every source.
    static func displayTitle(_ rawTitle: String?) -> String {
        let trimmed = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? String(localized: "(No title)") : trimmed
    }
}
