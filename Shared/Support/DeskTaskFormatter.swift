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
        if task.isEvent {
            if task.isAllDay { return String(localized: "All day · \(task.listName)") }
            guard let start = task.startDate else { return task.listName }
            let startText = timeFormatter.string(from: start)
            guard let end = task.endDate else { return "\(startText) · \(task.listName)" }
            return "\(startText) – \(timeFormatter.string(from: end)) · \(task.listName)"
        }

        guard let due = task.dueDate else { return task.listName }
        if task.isOverdue(at: now) {
            return String(localized: "Overdue · \(task.listName)")
        }
        if task.isAllDay { return String(localized: "To-do · \(task.listName)") }
        return String(localized: "Due \(timeFormatter.string(from: due)) · \(task.listName)")
    }

    /// Start time for compact week rows, or nil for all-day items and to-dos.
    static func startTime(for task: DeskTask) -> String? {
        guard task.isEvent, !task.isAllDay, let start = task.startDate else { return nil }
        return timeFormatter.string(from: start)
    }

    /// Label above the "Up next" card, e.g. "Up next · in 25 min", "Happening now" or "Overdue".
    static func upNextLabel(for task: DeskTask, now: Date = .now) -> String {
        if task.isEvent, !task.isAllDay, let start = task.startDate {
            if start <= now { return String(localized: "Happening now") }
            let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
            if minutes < 60 { return String(localized: "Up next · in \(minutes) min") }
            return String(localized: "Up next · at \(timeFormatter.string(from: start))")
        }
        if task.isOverdue(at: now) {
            return String(localized: "Overdue")
        }
        return String(localized: "Up next")
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

    /// "45 min", "1 h" or "1 h 30 min" for lengths chosen on the new-task form.
    static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return String(localized: "\(rest) min") }
        if rest == 0 { return String(localized: "\(hours) h") }
        return String(localized: "\(hours) h \(rest) min")
    }

    /// "12:30 left" for a session that can be resumed.
    static func timeLeft(_ remaining: TimeInterval) -> String {
        String(localized: "\(clock(remaining)) left")
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
