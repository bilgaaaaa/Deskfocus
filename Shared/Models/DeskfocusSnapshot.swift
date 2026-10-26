import Foundation

/// Everything the app and the widget share, persisted as one JSON file in the App Group container.
struct DeskfocusSnapshot: Codable, Equatable {
    var tasks: [DeskTask] = []
    /// Items checked off locally; hidden from the list until the next sync drops them.
    var completedTaskIds: Set<String> = []
    /// To-dos marked done that the app still has to complete in Reminders or Google Tasks.
    var pendingCompletionIds: Set<String> = []
    var focus: FocusSession?
    var settings = DeskfocusSettings()
    var lastSyncDate: Date?

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([DeskTask].self, forKey: .tasks) ?? []
        completedTaskIds = try container.decodeIfPresent(Set<String>.self, forKey: .completedTaskIds) ?? []
        pendingCompletionIds = try container.decodeIfPresent(Set<String>.self, forKey: .pendingCompletionIds) ?? []
        focus = try container.decodeIfPresent(FocusSession.self, forKey: .focus)
        settings = try container.decodeIfPresent(DeskfocusSettings.self, forKey: .settings) ?? DeskfocusSettings()
        lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate)
    }

    func task(withId id: String) -> DeskTask? {
        tasks.first { $0.id == id }
    }

    /// Today's list as shown to the user: not checked off and not already over.
    func visibleTasks(at now: Date) -> [DeskTask] {
        tasks.filter { !completedTaskIds.contains($0.id) && !$0.hasEnded(at: now) }
    }
}
