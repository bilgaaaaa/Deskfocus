import Foundation
import Observation
import WidgetKit

/// Merges every task source, keeps today's list in the shared state for the widget and pushes completions back.
@MainActor
@Observable
final class TaskRepository {
    /// Tasks from every available source for an interval, plus the names of sources that failed.
    struct FetchResult {
        let tasks: [DeskTask]
        let failedSources: [TaskSourceKind]
    }

    private(set) var isSyncing = false
    private(set) var lastErrorMessage: String?

    private let sources: [TaskSource]
    private var isProcessingCompletions = false

    init(sources: [TaskSource]) {
        self.sources = sources
    }

    /// Fetches any interval without saving it; used for browsing other days and weeks.
    func fetchTasks(in interval: DateInterval) async -> FetchResult {
        let settings = SharedStore.shared.load().settings
        var merged: [DeskTask] = []
        var failed: [TaskSourceKind] = []

        for source in sources where settings.enabledSources.contains(source.kind) && source.isAvailable {
            do {
                merged += try await source.fetchTasks(in: interval, settings: settings)
            } catch {
                Log.sync.error("\(source.kind.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                failed.append(source.kind)
            }
        }
        return FetchResult(tasks: Self.removingDuplicateEvents(merged).sortedForToday(), failedSources: failed)
    }

    /// False until the user granted access or connected the account behind this source.
    func isAvailable(_ kind: TaskSourceKind) -> Bool {
        sources.first { $0.kind == kind }?.isAvailable ?? false
    }

    /// Calendars and lists of every connected source, for the switches in Settings; a failing source is left out.
    func containers() async -> [TaskContainer] {
        var containers: [TaskContainer] = []
        for source in sources where source.isAvailable {
            do {
                containers += try await source.containers().sortedForDisplay()
            } catch {
                Log.sync.error("Could not list \(source.kind.rawValue, privacy: .public) calendars: \(error.localizedDescription, privacy: .public)")
            }
        }
        Log.sync.debug("Found \(containers.count) calendars and lists")
        return containers
    }

    /// Reloads today's list; a failing source keeps its previous tasks so one outage never empties the list.
    func refresh(now: Date = .now) async {
        guard !isSyncing else {
            Log.sync.debug("Refresh skipped, already syncing")
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        let previous = SharedStore.shared.load()
        let today = DateInterval.day(containing: now)
        let result = await fetchTasks(in: today)
        let kept = previous.tasks.filter { result.failedSources.contains($0.source) }
        let tasks = (result.tasks + kept).sortedForToday()
        let taskIds = Set(tasks.map(\.id))

        SharedStore.shared.update { snapshot in
            snapshot.tasks = tasks
            let pending = snapshot.pendingCompletionIds
            let focusTaskId = snapshot.focus?.taskId
            // Other-day items stay only while something still needs them. To-dos are done in their source
            // once synced, and a recurring one keeps its id, so its mark must not outlive the pending sync.
            snapshot.referencedTasks = snapshot.referencedTasks.filter { task in
                pending.contains(task.id)
                    || task.id == focusTaskId
                    || (task.isEvent && Self.isUpcoming(task, today: today))
            }
            let referencedEventIds = Set(snapshot.referencedTasks.filter(\.isEvent).map(\.id))
            snapshot.completedTaskIds = snapshot.completedTaskIds.filter {
                taskIds.contains($0) || pending.contains($0) || referencedEventIds.contains($0)
            }
            snapshot.completionDates = snapshot.completionDates.filter { $0.value >= today.start }
            // Unfinished sessions can be resumed for a week.
            let resumeLimit = today.start.addingTimeInterval(-7 * 86_400)
            snapshot.savedProgress = snapshot.savedProgress.filter { $0.value.savedAt >= resumeLimit }
            // Focus times are kept for two months after they were last picked.
            snapshot.pruneFocusMinutes(olderThan: today.start.addingTimeInterval(-60 * 86_400), now: now)
            snapshot.lastSyncDate = now
        }
        WidgetCenter.shared.reloadTimelines(ofKind: DeskfocusConstants.widgetKind)

        let failedNames = result.failedSources.map(\.displayName)
        lastErrorMessage = failedNames.isEmpty ? nil : String(localized: "Could not update \(failedNames.joined(separator: ", ")).")
        Log.sync.info("Synced \(tasks.count) items for today, \(failedNames.count) source failures")

        await processPendingCompletions()
    }

    /// Completes queued to-dos in Reminders or Google Tasks; failures stay queued for the next try.
    func processPendingCompletions() async {
        guard !isProcessingCompletions else { return }
        isProcessingCompletions = true
        defer { isProcessingCompletions = false }

        let snapshot = SharedStore.shared.load()
        guard !snapshot.pendingCompletionIds.isEmpty else { return }

        var done: Set<String> = []
        var dropped: Set<String> = []
        for taskId in snapshot.pendingCompletionIds {
            guard let task = snapshot.task(withId: taskId),
                  let source = sources.first(where: { $0.kind == task.source }) else {
                Log.sync.error("Dropping pending completion for unknown task")
                dropped.insert(taskId)
                continue
            }
            guard source.isAvailable else {
                Log.sync.info("Completion waits until \(task.source.rawValue, privacy: .public) is available")
                continue
            }
            do {
                try await source.complete(task)
                done.insert(taskId)
            } catch {
                Log.sync.error("Completion failed, will retry: \(error.localizedDescription, privacy: .public)")
            }
        }

        guard !done.isEmpty || !dropped.isEmpty else { return }
        SharedStore.shared.update { snapshot in
            snapshot.pendingCompletionIds.subtract(done.union(dropped))
            snapshot.completedTaskIds.subtract(dropped)
        }
    }

    /// True for items dated today or later; past items no longer need to be remembered.
    private static func isUpcoming(_ task: DeskTask, today: DateInterval) -> Bool {
        guard let date = task.endDate ?? task.dueDate ?? task.startDate else { return false }
        return date >= today.start
    }

    /// The same Google event can arrive through macOS Calendar and through Google directly; keep the first one.
    private static func removingDuplicateEvents(_ tasks: [DeskTask]) -> [DeskTask] {
        var seenEventKeys: Set<String> = []
        return tasks.filter { task in
            guard task.isEvent else { return true }
            let start = task.startDate.map { String(Int($0.timeIntervalSince1970)) } ?? "none"
            let key = "\(task.title.lowercased())|\(start)|\(task.isAllDay)"
            return seenEventKeys.insert(key).inserted
        }
    }
}
