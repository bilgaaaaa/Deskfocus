import Foundation

/// Open Google Tasks due in the interval (plus overdue and undated ones for today), across all task lists.
@MainActor
final class GoogleTasksSource: TaskSource {
    let kind: TaskSourceKind = .googleTasks
    private let auth: GoogleAuthService
    private let client: GoogleAPIClient
    private let baseURL = URL(string: "https://tasks.googleapis.com/tasks/v1")!
    /// Google Tasks has no list colors; use Google blue so its rows stay recognisable.
    private let listColorHex = "#1A73E8"

    init(auth: GoogleAuthService, client: GoogleAPIClient) {
        self.auth = auth
        self.client = client
    }

    var isAvailable: Bool { auth.isConnected }

    func fetchTasks(in interval: DateInterval, settings: DeskfocusSettings) async throws -> [DeskTask] {
        let lists = try await client.getAll(baseURL.appendingPathComponent("users/@me/lists"), as: GoogleTaskList.self)
        let query = [
            URLQueryItem(name: "showCompleted", value: "false"),
            URLQueryItem(name: "showHidden", value: "false"),
            URLQueryItem(name: "maxResults", value: "100")
        ]

        var tasks: [DeskTask] = []
        for list in lists {
            let tasksURL = URL(string: "\(baseURL.absoluteString)/lists/\(GoogleAPIClient.pathSegment(list.id))/tasks")!
            let items = try await client.getAll(tasksURL, query: query, as: GoogleTaskItem.self)
            tasks += items.compactMap { item in
                guard item.status != "completed" else { return nil }
                let dueDate = GoogleDateParser.taskDueDay(item.due)
                guard DeskTask.isDue(dueDate, in: interval, includeUndated: settings.includeUndatedTasks) else { return nil }
                return DeskTask(
                    id: DeskTask.makeId(source: kind, containerIdentifier: list.id, sourceIdentifier: item.id),
                    source: kind,
                    sourceIdentifier: item.id,
                    containerIdentifier: list.id,
                    title: DeskTask.displayTitle(item.title),
                    startDate: nil,
                    endDate: nil,
                    dueDate: dueDate,
                    isAllDay: true,
                    listName: list.title ?? "Google Tasks",
                    colorHex: listColorHex
                )
            }
        }
        Log.sync.debug("Google Tasks returned \(tasks.count) tasks from \(lists.count) lists")
        return tasks
    }

    func complete(_ task: DeskTask) async throws {
        let taskURL = URL(string: "\(baseURL.absoluteString)/lists/\(GoogleAPIClient.pathSegment(task.containerIdentifier))/tasks/\(GoogleAPIClient.pathSegment(task.sourceIdentifier))")!
        try await client.patch(taskURL, json: ["status": "completed"])
        Log.sync.info("Task completed in Google Tasks")
    }
}
