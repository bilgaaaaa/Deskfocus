import Foundation

/// Where a task or event comes from; also decides whether it can be completed remotely.
enum TaskSourceKind: String, Codable, CaseIterable, Hashable {
    case appleCalendar
    case appleReminders
    case googleCalendar
    case googleTasks

    /// Calendar events have no "done" state remotely, so they are only checked off locally.
    var isEvent: Bool {
        self == .appleCalendar || self == .googleCalendar
    }

    var displayName: String {
        switch self {
        case .appleCalendar: return "iCloud Calendar"
        case .appleReminders: return "iCloud Reminders"
        case .googleCalendar: return "Google Calendar"
        case .googleTasks: return "Google Tasks"
        }
    }
}
