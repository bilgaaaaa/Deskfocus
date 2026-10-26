import Foundation

/// Converts Google's RFC 3339 timestamps and plain dates into local `Date`s.
enum GoogleDateParser {
    private static let internetFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func timestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        return internetFormatter.date(from: value) ?? fractionalFormatter.date(from: value)
    }

    /// "yyyy-MM-dd" as local midnight, for all-day events.
    static func localDay(_ value: String?) -> Date? {
        guard let value else { return nil }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Google Tasks stores only a date at midnight UTC; keep that calendar day in the local time zone.
    static func taskDueDay(_ value: String?) -> Date? {
        guard let instant = timestamp(value) else { return nil }
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = utcCalendar.dateComponents([.year, .month, .day], from: instant)
        return Calendar.current.date(from: components)
    }

    /// UTC timestamp for API query parameters such as `timeMin`.
    static func queryString(_ date: Date) -> String {
        internetFormatter.string(from: date)
    }
}
