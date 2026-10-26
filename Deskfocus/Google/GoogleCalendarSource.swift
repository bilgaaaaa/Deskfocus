import Foundation

/// Events in the interval from every calendar the user shows in Google Calendar.
@MainActor
final class GoogleCalendarSource: TaskSource {
    let kind: TaskSourceKind = .googleCalendar
    private let auth: GoogleAuthService
    private let client: GoogleAPIClient
    private let baseURL = URL(string: "https://www.googleapis.com/calendar/v3")!

    init(auth: GoogleAuthService, client: GoogleAPIClient) {
        self.auth = auth
        self.client = client
    }

    var isAvailable: Bool { auth.isConnected }

    func fetchTasks(in interval: DateInterval, settings: DeskfocusSettings) async throws -> [DeskTask] {
        let calendars = try await client.getAll(
            baseURL.appendingPathComponent("users/me/calendarList"),
            as: GoogleCalendarListEntry.self
        ).filter { $0.selected != false && $0.hidden != true }

        let query = [
            URLQueryItem(name: "timeMin", value: GoogleDateParser.queryString(interval.start)),
            URLQueryItem(name: "timeMax", value: GoogleDateParser.queryString(interval.end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "2500")
        ]

        var tasks: [DeskTask] = []
        for calendar in calendars {
            let eventsURL = URL(string: "\(baseURL.absoluteString)/calendars/\(GoogleAPIClient.pathSegment(calendar.id))/events")!
            let events = try await client.getAll(eventsURL, query: query, as: GoogleEvent.self)
            let listName = calendar.summaryOverride ?? calendar.summary ?? "Google Calendar"
            tasks += events.compactMap { makeTask(from: $0, calendar: calendar, listName: listName) }
        }
        Log.sync.debug("Google Calendar returned \(tasks.count) events from \(calendars.count) calendars")
        return tasks
    }

    /// Events have no remote done state; checking one off stays local.
    func complete(_ task: DeskTask) async throws {}

    private func makeTask(from event: GoogleEvent, calendar: GoogleCalendarListEntry, listName: String) -> DeskTask? {
        guard event.status != "cancelled" else { return nil }

        let isAllDay = event.start?.date != nil
        let start = isAllDay ? GoogleDateParser.localDay(event.start?.date) : GoogleDateParser.timestamp(event.start?.dateTime)
        let end = isAllDay ? GoogleDateParser.localDay(event.end?.date) : GoogleDateParser.timestamp(event.end?.dateTime)
        guard let start else {
            Log.sync.debug("Skipped Google event without a start date")
            return nil
        }

        return DeskTask(
            id: DeskTask.makeId(source: kind, containerIdentifier: calendar.id, sourceIdentifier: event.id, occurrence: start),
            source: kind,
            sourceIdentifier: event.id,
            containerIdentifier: calendar.id,
            title: DeskTask.displayTitle(event.summary),
            startDate: start,
            endDate: end,
            dueDate: nil,
            isAllDay: isAllDay,
            listName: listName,
            colorHex: calendar.backgroundColor
        )
    }
}
