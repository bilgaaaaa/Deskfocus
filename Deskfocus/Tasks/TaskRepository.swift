import Foundation
import Observation
import WidgetKit

/// Merges every task source into today's list, saves it for the widget and pushes completions back to the sources.
@MainActor
@Observable
final class TaskRepository {
    private(set) var isSyncing = false
    private(set) var lastErrorMessage: String?

    private let sources: [TaskSource]
    private var isProcessingCompletions = false

    init(sources: [TaskSource]) {
        self.sources = sources
    }

    /// Reloads today's tasks; a failing source keeps its previous tasks so one outage never empties the list.
    func refresh(now: Date = .now) async {
        guard !isSyncing else {
            Log.sync.debug("Refresh skipped, already syncing")
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        let previous = SharedStore.shared.load()
        let settings = previous.settings
        let day = DateInterval.day(containing: now)
        var merged: [DeskTask] = []
        var failures: [String] = []

        for source in sources where settings.enabledSources.contains(source.kind) && source.isAvailable {
            do {
                merged += try await source.fetchTasks(in: day, settings: settings)
            } catch {
                Log.sync.error("\(source.kind.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                failures.append(source.kind.displayName)
                merged += previous.tasks.filter { $0.source == source.kind }
            }
        }

        let tasks = Self.removingDuplicateEvents(merged).sortedForToday()
        let taskIds = Set(tasks.map(\.id))
        SharedStore.shared.update { snapshot in
            snapshot.tasks = tasks
            // Keep a checked-off mark only while its item is still listed or still waiting to sync.
            let pending = snapshot.pendingCompletionIds
            snapshot.completedTaskIds = snapshot.completedTaskIds.filter { taskIds.contains($0) || pending.contains($0) }
            snapshot.lastSyncDate = now
        }
        WidgetCenter.shared.reloadTimelines(ofKind: DeskfocusConstants.widgetKind)

        lastErrorMessage = failures.isEmpty ? nil : "Could not update \(failures.joined(separator: ", "))."
        Log.sync.info("Synced \(tasks.count) items, \(failures.count) source failures")

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
