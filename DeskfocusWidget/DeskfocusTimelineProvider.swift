import WidgetKit

struct DeskfocusEntry: TimelineEntry {
    let date: Date
    let snapshot: DeskfocusSnapshot
}

/// Builds widget timelines from the shared state: an entry every minute so "in 25 min" and the focus ring keep moving,
/// plus one at the timer's end so it flips to "Time's up" on time.
struct DeskfocusTimelineProvider: TimelineProvider {
    /// Upper bound between reloads so ended events drop off even when nothing else changes.
    private let maximumRefreshInterval: TimeInterval = 15 * 60
    private let tickInterval: TimeInterval = 60
    /// Cap on minute entries in one timeline; a longer session reloads where they run out.
    private let maximumTicks = 120

    func placeholder(in context: Context) -> DeskfocusEntry {
        DeskfocusEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (DeskfocusEntry) -> Void) {
        let snapshot = context.isPreview ? DeskfocusSnapshot.preview : SharedStore.shared.load()
        completion(DeskfocusEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeskfocusEntry>) -> Void) {
        let now = Date()
        let snapshot = SharedStore.shared.load()
        // The widget process restarts often, so a new language shows up shortly after it is chosen.
        LanguagePreference.apply(snapshot.settings.language)
        var dates: Set<Date> = [now]
        var nextRefresh = now.addingTimeInterval(maximumRefreshInterval)

        if case .running(let endDate) = snapshot.focus?.phase(at: now) {
            dates.insert(endDate)
            nextRefresh = max(nextRefresh, endDate.addingTimeInterval(1))
        }

        // Re-render right after the next timed event ends so it leaves the list.
        if let nextEventEnd = snapshot.visibleTasks(at: now).compactMap({ $0.isEvent && !$0.isAllDay ? $0.endDate : nil }).min(),
           nextEventEnd < nextRefresh {
            dates.insert(nextEventEnd)
        }

        let ticks = minuteTicks(after: now, until: nextRefresh)
        dates.formUnion(ticks)
        // The cap cut the ticks short of the refresh: reload when they run out so nothing freezes.
        if ticks.count == maximumTicks, let lastTick = ticks.last {
            nextRefresh = min(nextRefresh, lastTick)
        }

        let entries = dates.sorted().map { DeskfocusEntry(date: $0, snapshot: snapshot) }
        Log.widget.debug("Timeline with \(entries.count) entries")
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    /// Whole clock minutes after `start`, up to `end` and at most `maximumTicks` of them.
    private func minuteTicks(after start: Date, until end: Date) -> [Date] {
        let first = (start.timeIntervalSinceReferenceDate / tickInterval).rounded(.down) * tickInterval + tickInterval
        let last = min(end.timeIntervalSinceReferenceDate, first + tickInterval * Double(maximumTicks - 1))
        guard first <= last else { return [] }
        return stride(from: first, through: last, by: tickInterval).map { Date(timeIntervalSinceReferenceDate: $0) }
    }
}

extension DeskfocusSnapshot {
    /// Sample content for the widget gallery.
    static var preview: DeskfocusSnapshot {
        let now = Date()
        var snapshot = DeskfocusSnapshot()
        snapshot.tasks = [
            DeskTask(id: "preview-1", source: .googleCalendar, sourceIdentifier: "1", containerIdentifier: "work", title: "Design review", startDate: now.addingTimeInterval(1800), endDate: now.addingTimeInterval(3600), dueDate: nil, isAllDay: false, listName: "Work", colorHex: "#4285F4"),
            DeskTask(id: "preview-2", source: .appleReminders, sourceIdentifier: "2", containerIdentifier: "home", title: "Write the weekly report", startDate: nil, endDate: nil, dueDate: now, isAllDay: true, listName: "Reminders", colorHex: "#FF9500"),
            DeskTask(id: "preview-3", source: .googleTasks, sourceIdentifier: "3", containerIdentifier: "list", title: "Book flights", startDate: nil, endDate: nil, dueDate: now, isAllDay: true, listName: "My Tasks", colorHex: "#1A73E8")
        ]
        return snapshot
    }
}
