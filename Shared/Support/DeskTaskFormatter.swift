import Foundation

/// Text shown for tasks and timers, shared so the menu bar and the widget always read the same.
enum DeskTaskFormatter {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Short line under a task title, e.g. "10:00 – 11:00", "Overdue" or the list name.
    static func subtitle(for task: DeskTask, now: Date = .now) -> String {
        let calendar = Calendar.current

        if task.isEvent {
            if task.isAllDay { return "All day · \(task.listName)" }
            guard let start = task.startDate else { return task.listName }
            let startText = timeFormatter.string(from: start)
            guard let end = task.endDate else { return startText }
            return "\(startText) – \(timeFormatter.string(from: end))"
        }

        guard let due = task.dueDate else { return task.listName }
        if calendar.startOfDay(for: due) < calendar.startOfDay(for: now) {
            return "Overdue · \(task.listName)"
        }
        if task.isAllDay { return "Today · \(task.listName)" }
        return "Due \(timeFormatter.string(from: due)) · \(task.listName)"
    }

    /// Remaining time as "mm:ss", or "h:mm:ss" for an hour or more.
    static func clock(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
