import AppIntents

/// Starts a focus timer for one task; used by the widget's play buttons.
struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let description = IntentDescription("Starts a focus timer for a task from today's list.")
    static let isDiscoverable = false

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}

    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        FocusController.start(taskId: taskId)
        return .result()
    }
}

/// Checks a task off and ends its focus session if one is running.
struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"
    static let description = IntentDescription("Marks a task from today's list as done.")
    static let isDiscoverable = false

    @Parameter(title: "Task ID")
    var taskId: String

    init() {}

    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        FocusController.complete(taskId: taskId)
        return .result()
    }
}

struct PauseFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Focus"
    static let description = IntentDescription("Pauses the running focus timer.")

    func perform() async throws -> some IntentResult {
        FocusController.pause()
        return .result()
    }
}

struct ResumeFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Focus"
    static let description = IntentDescription("Resumes a paused focus timer.")

    func perform() async throws -> some IntentResult {
        FocusController.resume()
        return .result()
    }
}

struct StopFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Focus"
    static let description = IntentDescription("Ends the focus session without completing the task.")

    func perform() async throws -> some IntentResult {
        FocusController.stop()
        return .result()
    }
}
