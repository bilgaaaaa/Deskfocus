import EventKit

/// Incomplete reminders due in the interval (plus overdue and undated ones for today) from macOS Reminders.
@MainActor
final class AppleRemindersSource: TaskSource {
    enum RemindersError: LocalizedError {
        case reminderNotFound

        var errorDescription: String? { String(localized: "The reminder no longer exists.") }
    }

    let kind: TaskSourceKind = .appleReminders
    private let access: EventKitAccess

    init(access: EventKitAccess) {
        self.access = access
    }

    var isAvailable: Bool { access.hasRemindersAccess }

    func containers() async throws -> [TaskContainer] {
        access.store.calendars(for: .reminder).map { list in
            TaskContainer(
                source: kind,
                identifier: list.calendarIdentifier,
                title: list.title,
                accountName: list.source.title,
                colorHex: list.color?.hexString
            )
        }
    }

    func fetchTasks(in interval: DateInterval, settings: DeskfocusSettings) async throws -> [DeskTask] {
        // Copied so the EventKit callback below never touches self.
        let kind = kind
        let lists = access.store.calendars(for: .reminder)
            .filter { settings.isContainerVisible(source: kind, containerIdentifier: $0.calendarIdentifier) }
        // An empty list would mean "all lists" to EventKit, so stop here when every list is off.
        guard !lists.isEmpty else {
            Log.sync.debug("Every reminders list is switched off")
            return []
        }
        let predicate = access.store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: lists)
        let includeUndated = settings.includeUndatedTasks

        // Map inside the callback so no EventKit objects cross threads.
        let tasks: [DeskTask] = await withCheckedContinuation { continuation in
            access.store.fetchReminders(matching: predicate) { reminders in
                let calendar = Calendar.current
                let mapped = (reminders ?? []).compactMap { reminder -> DeskTask? in
                    let dueDate = reminder.dueDateComponents.flatMap { calendar.date(from: $0) }
                    guard DeskTask.isDue(dueDate, in: interval, includeUndated: includeUndated) else { return nil }
                    return DeskTask(
                        id: DeskTask.makeId(source: kind, containerIdentifier: reminder.calendar.calendarIdentifier, sourceIdentifier: reminder.calendarItemIdentifier),
                        source: kind,
                        sourceIdentifier: reminder.calendarItemIdentifier,
                        containerIdentifier: reminder.calendar.calendarIdentifier,
                        title: DeskTask.displayTitle(reminder.title),
                        startDate: nil,
                        endDate: nil,
                        dueDate: dueDate,
                        isAllDay: reminder.dueDateComponents?.hour == nil,
                        listName: reminder.calendar.title,
                        colorHex: reminder.calendar.color?.hexString
                    )
                }
                continuation.resume(returning: mapped)
            }
        }
        Log.sync.debug("Apple Reminders returned \(tasks.count) reminders from \(lists.count) lists")
        return tasks
    }

    func complete(_ task: DeskTask) async throws {
        guard let reminder = access.store.calendarItem(withIdentifier: task.sourceIdentifier) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }
        reminder.isCompleted = true
        try access.store.save(reminder, commit: true)
        Log.sync.info("Reminder completed in Apple Reminders")
    }
}
