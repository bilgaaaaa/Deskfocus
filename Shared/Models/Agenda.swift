import Foundation

/// Puts tasks on the days they belong to: events on every day they overlap, to-dos on their due day,
/// and overdue or undated to-dos on today.
enum Agenda {
    static func tasks(_ tasks: [DeskTask], on day: DateInterval, today: DateInterval) -> [DeskTask] {
        let isToday = day.start == today.start
        return tasks.filter { task in
            if task.isEvent {
                guard let start = task.startDate else { return false }
                // Zero-length events still need a moment on their day.
                let end = max(task.endDate ?? start, start.addingTimeInterval(1))
                return start < day.end && end > day.start
            }
            guard let due = task.dueDate else { return isToday }
            if due >= day.start && due < day.end { return true }
            return isToday && due < today.start
        }
        .sortedForToday()
    }

    /// Monday-to-Sunday style week (following the user's first weekday) that contains the date.
    static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval.day(containing: date, calendar: calendar)
    }

    /// The start of each day in an interval.
    static func days(in interval: DateInterval, calendar: Calendar = .current) -> [Date] {
        var days: [Date] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }
}

extension DateInterval {
    /// Midnight to midnight of the given day in the current calendar.
    static func day(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }
}
