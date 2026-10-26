import EventKit
import Foundation

/// A calendar or list a new task can be added to.
struct AddTaskTarget: Identifiable, Hashable {
    enum Kind: String, Hashable {
        /// A calendar in macOS Calendar (iCloud, Google, Outlook…): creates an event with a time and length.
        case event
        /// A list in macOS Reminders: creates a to-do.
        case reminder
        /// A Google Tasks list: creates a to-do.
        case googleTask
    }

    let kind: Kind
    /// EventKit calendar identifier or Google task list id.
    let identifier: String
    let title: String
    let accountName: String

    var id: String { "\(kind.rawValue)|\(identifier)" }
    var createsEvent: Bool { kind == .event }
}

/// What the user filled in on the "New task" window.
struct NewTaskDraft {
    let title: String
    let target: AddTaskTarget
    /// Event start, or the to-do's due day.
    let date: Date
    /// Event length in minutes.
    let eventMinutes: Int
    /// False for a to-do without a due date.
    let hasDueDate: Bool
    /// Focus time remembered for a to-do.
    let focusMinutes: Int
}

/// Lists writable calendars and lists, and creates events and to-dos in them.
@MainActor
final class TaskCreationService {
    enum CreationError: LocalizedError {
        case calendarNotFound
        case missingTaskId

        var errorDescription: String? {
            switch self {
            case .calendarNotFound: return String(localized: "That calendar or list is no longer available.")
            case .missingTaskId: return String(localized: "Google did not confirm the new task. Please try again.")
            }
        }
    }

    private let eventKit: EventKitAccess
    private let googleAuth: GoogleAuthService
    private let googleClient: GoogleAPIClient
    private let googleTasksURL = URL(string: "https://tasks.googleapis.com/tasks/v1")!

    init(eventKit: EventKitAccess, googleAuth: GoogleAuthService, googleClient: GoogleAPIClient) {
        self.eventKit = eventKit
        self.googleAuth = googleAuth
        self.googleClient = googleClient
    }

    /// Every calendar and list the user can write to, calendars first.
    func targets() async -> [AddTaskTarget] {
        var targets: [AddTaskTarget] = []
        let store = eventKit.store

        if eventKit.hasCalendarAccess {
            targets += store.calendars(for: .event)
                .filter(\.allowsContentModifications)
                .map { AddTaskTarget(kind: .event, identifier: $0.calendarIdentifier, title: $0.title, accountName: $0.source.title) }
                .sorted { ($0.accountName, $0.title) < ($1.accountName, $1.title) }
        }
        if eventKit.hasRemindersAccess {
            targets += store.calendars(for: .reminder)
                .filter(\.allowsContentModifications)
                .map { AddTaskTarget(kind: .reminder, identifier: $0.calendarIdentifier, title: $0.title, accountName: $0.source.title) }
                .sorted { ($0.accountName, $0.title) < ($1.accountName, $1.title) }
        }
        if googleAuth.isConnected {
            do {
                let lists = try await googleClient.getAll(googleTasksURL.appendingPathComponent("users/@me/lists"), as: GoogleTaskList.self)
                targets += lists.map {
                    AddTaskTarget(kind: .googleTask, identifier: $0.id, title: $0.title ?? "Google Tasks", accountName: googleAuth.connectedEmail ?? "Google")
                }
            } catch {
                Log.google.error("Could not load Google task lists: \(error.localizedDescription, privacy: .public)")
            }
        }
        Log.sync.debug("Found \(targets.count) places to add tasks")
        return targets
    }

    /// Creates the event or to-do and returns its Deskfocus id.
    func create(_ draft: NewTaskDraft) async throws -> String {
        switch draft.target.kind {
        case .event: return try createEvent(draft)
        case .reminder: return try createReminder(draft)
        case .googleTask: return try await createGoogleTask(draft)
        }
    }

    private func createEvent(_ draft: NewTaskDraft) throws -> String {
        let store = eventKit.store
        guard let calendar = store.calendar(withIdentifier: draft.target.identifier) else { throw CreationError.calendarNotFound }

        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.calendar = calendar
        event.startDate = draft.date
        event.endDate = draft.date.addingTimeInterval(TimeInterval(max(draft.eventMinutes, 5) * 60))
        try store.save(event, span: .thisEvent, commit: true)

        Log.sync.info("Event created in \(calendar.source.title, privacy: .public)")
        return DeskTask.makeId(source: .appleCalendar, containerIdentifier: calendar.calendarIdentifier, sourceIdentifier: event.calendarItemIdentifier, occurrence: event.startDate)
    }

    private func createReminder(_ draft: NewTaskDraft) throws -> String {
        let store = eventKit.store
        guard let calendar = store.calendar(withIdentifier: draft.target.identifier) else { throw CreationError.calendarNotFound }

        let reminder = EKReminder(eventStore: store)
        reminder.title = draft.title
        reminder.calendar = calendar
        if draft.hasDueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: draft.date)
        }
        try store.save(reminder, commit: true)

        Log.sync.info("Reminder created in \(calendar.title, privacy: .public)")
        return DeskTask.makeId(source: .appleReminders, containerIdentifier: calendar.calendarIdentifier, sourceIdentifier: reminder.calendarItemIdentifier)
    }

    private func createGoogleTask(_ draft: NewTaskDraft) async throws -> String {
        let listId = draft.target.identifier
        let url = URL(string: "\(googleTasksURL.absoluteString)/lists/\(GoogleAPIClient.pathSegment(listId))/tasks")!
        var body: [String: Any] = ["title": draft.title]
        if draft.hasDueDate {
            body["due"] = Self.googleDueString(for: draft.date)
        }
        let created: GoogleTaskItem = try await googleClient.post(url, json: body)
        guard !created.id.isEmpty else { throw CreationError.missingTaskId }

        Log.sync.info("Google task created")
        return DeskTask.makeId(source: .googleTasks, containerIdentifier: listId, sourceIdentifier: created.id)
    }

    /// Google Tasks keeps only a date, sent as midnight UTC of the local calendar day.
    private static func googleDueString(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02dT00:00:00.000Z", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }
}
