import Foundation

/// Time left on a task whose session ended early, so ▶ resumes it instead of starting over.
struct SavedFocusProgress: Codable, Equatable {
    var remaining: TimeInterval
    var planned: TimeInterval
    var savedAt: Date
}

/// Everything the app and the widget share, persisted as one JSON file in the App Group container.
struct DeskfocusSnapshot: Codable, Equatable {
    /// Today's list, as shown by the widget.
    var tasks: [DeskTask] = []
    /// Items from other days the user started or checked off, so actions can find them.
    var referencedTasks: [DeskTask] = []
    /// Items checked off locally; hidden from every list until a sync drops them.
    var completedTaskIds: Set<String> = []
    /// To-dos marked done that the app still has to complete in Reminders or Google Tasks.
    var pendingCompletionIds: Set<String> = []
    /// When each item was checked off, so "done today" stays right after synced items disappear.
    var completionDates: [String: Date] = [:]
    /// Focus time the user picked for a to-do, in minutes.
    var taskFocusMinutes: [String: Int] = [:]
    /// Unfinished sessions by task id, resumed by the next ▶ on that task.
    var savedProgress: [String: SavedFocusProgress] = [:]
    var focus: FocusSession?
    var settings = DeskfocusSettings()
    var lastSyncDate: Date?

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([DeskTask].self, forKey: .tasks) ?? []
        referencedTasks = try container.decodeIfPresent([DeskTask].self, forKey: .referencedTasks) ?? []
        completedTaskIds = try container.decodeIfPresent(Set<String>.self, forKey: .completedTaskIds) ?? []
        pendingCompletionIds = try container.decodeIfPresent(Set<String>.self, forKey: .pendingCompletionIds) ?? []
        completionDates = try container.decodeIfPresent([String: Date].self, forKey: .completionDates) ?? [:]
        taskFocusMinutes = try container.decodeIfPresent([String: Int].self, forKey: .taskFocusMinutes) ?? [:]
        savedProgress = try container.decodeIfPresent([String: SavedFocusProgress].self, forKey: .savedProgress) ?? [:]
        focus = try container.decodeIfPresent(FocusSession.self, forKey: .focus)
        settings = try container.decodeIfPresent(DeskfocusSettings.self, forKey: .settings) ?? DeskfocusSettings()
        lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate)
    }

    func task(withId id: String) -> DeskTask? {
        tasks.first(where: { $0.id == id }) ?? referencedTasks.first(where: { $0.id == id })
    }

    /// Today's list as shown to the user: not checked off and not already over.
    func visibleTasks(at now: Date) -> [DeskTask] {
        tasks.filter { !completedTaskIds.contains($0.id) && !$0.hasEnded(at: now) }
    }

    /// How many items were checked off today, for the progress ring.
    func completedCount(on day: Date) -> Int {
        completionDates.values.filter { Calendar.current.isDate($0, inSameDayAs: day) }.count
    }

    /// Remembers a task from another day so focus and completion can find it later.
    mutating func reference(_ task: DeskTask) {
        guard self.task(withId: task.id) == nil else { return }
        referencedTasks.append(task)
    }
}
