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

    /// Calendars and Reminders include every account added in macOS, not only iCloud.
    var displayName: String {
        switch self {
        case .appleCalendar: return "Calendars"
        case .appleReminders: return "Reminders"
        case .googleCalendar: return "Google Calendar (direct)"
        case .googleTasks: return "Google Tasks"
        }
    }

    /// Sources that need Deskfocus' own Google sign-in, rather than the accounts added in macOS.
    var requiresGoogleSignIn: Bool {
        self == .googleCalendar || self == .googleTasks
    }
}
