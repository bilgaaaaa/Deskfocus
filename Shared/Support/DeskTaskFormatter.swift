import Foundation

/// Text shown for tasks, days and timers, shared so every surface reads the same.
enum DeskTaskFormatter {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()

    private static let shortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter
    }()

    private static let shortDayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    /// Short line under a task title, e.g. "10:00 – 11:00", "Overdue · Reminders" or the list name.
    static func subtitle(for task: DeskTask, now: Date = .now) -> String {
        let calendar = Calendar.current

        if task.isEvent {
            if task.isAllDay { return "All day · \(task.listName)" }
            guard let start = task.startDate else { return task.listName }
            let startText = timeFormatter.string(from: start)
            guard let end = task.endDate else { return "\(startText) · \(task.listName)" }
            return "\(startText) – \(timeFormatter.string(from: end)) · \(task.listName)"
        }

        guard let due = task.dueDate else { return task.listName }
        if calendar.startOfDay(for: due) < calendar.startOfDay(for: now) {
            return "Overdue · \(task.listName)"
        }
        if task.isAllDay { return "To-do · \(task.listName)" }
        return "Due \(timeFormatter.string(from: due)) · \(task.listName)"
    }

    /// Start time for compact week rows, or nil for all-day items and to-dos.
    static func startTime(for task: DeskTask) -> String? {
        guard task.isEvent, !task.isAllDay, let start = task.startDate else { return nil }
        return timeFormatter.string(from: start)
    }

    /// Label above the "Up next" card, e.g. "Up next · in 25 min", "Happening now" or "Overdue".
    static func upNextLabel(for task: DeskTask, now: Date = .now) -> String {
        if task.isEvent, !task.isAllDay, let start = task.startDate {
            if start <= now { return "Happening now" }
            let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
            if minutes < 60 { return "Up next · in \(minutes) min" }
            return "Up next · at \(timeFormatter.string(from: start))"
        }
        if let due = task.dueDate, Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: now) {
            return "Overdue"
        }
        return "Up next"
    }

    /// "Monday" style weekday, the small amber label above the date.
    static func weekday(_ date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    /// "Mon" style weekday for week columns.
    static func shortWeekday(_ date: Date) -> String {
        shortWeekdayFormatter.string(from: date)
    }

    /// "26 October" style date for headers.
    static func dayMonth(_ date: Date) -> String {
        dayMonthFormatter.string(from: date)
    }

    /// "26 Oct – 1 Nov" for the week header.
    static func weekRange(_ week: DateInterval) -> String {
        let lastDay = week.end.addingTimeInterval(-1)
        return "\(shortDayMonthFormatter.string(from: week.start)) – \(shortDayMonthFormatter.string(from: lastDay))"
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
