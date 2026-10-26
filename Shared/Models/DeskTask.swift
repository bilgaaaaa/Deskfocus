import Foundation

/// One item on today's list: a calendar event or a to-do, normalised across all sources.
struct DeskTask: Codable, Identifiable, Hashable {
    let id: String
    let source: TaskSourceKind
    /// Identifier inside the source (EventKit calendar item id, Google event or task id).
    let sourceIdentifier: String
    /// Calendar id or task list id the item belongs to.
    let containerIdentifier: String
    var title: String
    var startDate: Date?
    var endDate: Date?
    var dueDate: Date?
    var isAllDay: Bool
    var listName: String
    var colorHex: String?

    var isEvent: Bool { source.isEvent }

    /// Date used to order the day's list; undated items sort last.
    var sortDate: Date? { startDate ?? dueDate }

    /// Builds a stable id; events add the occurrence start so recurring events stay unique per day.
    static func makeId(source: TaskSourceKind, containerIdentifier: String, sourceIdentifier: String, occurrence: Date? = nil) -> String {
        var id = "\(source.rawValue)|\(containerIdentifier)|\(sourceIdentifier)"
        if let occurrence {
            id += "|\(Int(occurrence.timeIntervalSince1970))"
        }
        return id
    }

    /// True once a timed event is over; to-dos never expire on their own.
    func hasEnded(at now: Date) -> Bool {
        guard isEvent, !isAllDay, let endDate else { return false }
        return endDate <= now
    }
}

extension Array where Element == DeskTask {
    /// Dated items first by time, then undated items alphabetically.
    func sortedForToday() -> [DeskTask] {
        sorted { lhs, rhs in
            switch (lhs.sortDate, rhs.sortDate) {
            case let (left?, right?):
                return left == right ? lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending : left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }
}
