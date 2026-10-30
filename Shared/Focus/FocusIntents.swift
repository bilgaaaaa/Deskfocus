import AppIntents

/// Lets the app finish its own follow-up before a button's intent returns.
/// Only the iPhone app sets it: its widget and Live Activity buttons run in the app's process, which may be suspended right after.
@MainActor
enum FocusIntentObserver {
    static var stateDidChange: (@MainActor () async -> Void)?
}

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

    @MainActor
    func perform() async throws -> some IntentResult {
        FocusController.start(taskId: taskId)
        await FocusIntentObserver.stateDidChange?()
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

    @MainActor
    func perform() async throws -> some IntentResult {
        FocusController.complete(taskId: taskId)
        await FocusIntentObserver.stateDidChange?()
        return .result()
    }
}

struct PauseFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Focus"
    static let description = IntentDescription("Pauses the running focus timer.")

    @MainActor
    func perform() async throws -> some IntentResult {
        FocusController.pause()
        await FocusIntentObserver.stateDidChange?()
        return .result()
    }
}

struct ResumeFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Focus"
    static let description = IntentDescription("Resumes a paused focus timer.")

    @MainActor
    func perform() async throws -> some IntentResult {
        FocusController.resume()
        await FocusIntentObserver.stateDidChange?()
        return .result()
    }
}

/// Adds five minutes to the session, also once the time is up; used by the "+5 min" buttons.
struct ExtendFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Extend Focus"
    static let description = IntentDescription("Adds five minutes to the focus timer.")

    @MainActor
    func perform() async throws -> some IntentResult {
        FocusController.extend()
        await FocusIntentObserver.stateDidChange?()
        return .result()
    }
}

/// Ends a session without completing the task; with no task ID it ends the current one.
struct EndFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "End Focus"
    static let description = IntentDescription("Ends the focus session without completing the task.")

    @Parameter(title: "Task ID")
    var taskId: String?

    init() {}

    init(taskId: String?) {
        self.taskId = taskId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        FocusController.end(taskId: taskId)
        await FocusIntentObserver.stateDidChange?()
        return .result()
    }
}

#if os(iOS)
// Live Activity intents run in the app's process, even when pressed in the widget or on the Lock Screen,
// so the app can schedule the alert and start or update the Live Activity right away.
extension StartFocusIntent: LiveActivityIntent {}
extension CompleteTaskIntent: LiveActivityIntent {}
extension PauseFocusIntent: LiveActivityIntent {}
extension ResumeFocusIntent: LiveActivityIntent {}
extension ExtendFocusIntent: LiveActivityIntent {}
extension EndFocusIntent: LiveActivityIntent {}
#endif
