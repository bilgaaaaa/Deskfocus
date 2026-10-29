import EventKit

/// Events in the interval from the calendars in macOS Calendar (iCloud and any accounts added in System Settings).
@MainActor
final class AppleCalendarSource: TaskSource {
    let kind: TaskSourceKind = .appleCalendar
    private let access: EventKitAccess

    init(access: EventKitAccess) {
        self.access = access
    }

    var isAvailable: Bool { access.hasCalendarAccess }

    func containers() async throws -> [TaskContainer] {
        access.store.calendars(for: .event).map { calendar in
            TaskContainer(
                source: kind,
                identifier: calendar.calendarIdentifier,
                title: calendar.title,
                accountName: calendar.source.title,
                colorHex: calendar.color?.hexString
            )
        }
    }

    func fetchTasks(in interval: DateInterval, settings: DeskfocusSettings) async throws -> [DeskTask] {
        let calendars = access.store.calendars(for: .event)
            .filter { settings.isContainerVisible(source: kind, containerIdentifier: $0.calendarIdentifier) }
        // An empty list would mean "all calendars" to EventKit, so stop here when every calendar is off.
        guard !calendars.isEmpty else {
            Log.sync.debug("Every Apple calendar is switched off")
            return []
        }
        let predicate = access.store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        let events = access.store.events(matching: predicate).filter { $0.status != .canceled }

        let tasks = events.map { event in
            DeskTask(
                id: DeskTask.makeId(source: kind, containerIdentifier: event.calendar.calendarIdentifier, sourceIdentifier: event.calendarItemIdentifier, occurrence: event.startDate),
                source: kind,
                sourceIdentifier: event.calendarItemIdentifier,
                containerIdentifier: event.calendar.calendarIdentifier,
                title: DeskTask.displayTitle(event.title),
                startDate: event.startDate,
                endDate: event.endDate,
                dueDate: nil,
                isAllDay: event.isAllDay,
                listName: event.calendar.title,
                colorHex: event.calendar.color?.hexString
            )
        }
        Log.sync.debug("Apple Calendar returned \(tasks.count) events from \(calendars.count) calendars")
        return tasks
    }

    /// Events have no remote done state; checking one off stays local.
    func complete(_ task: DeskTask) async throws {}
}
