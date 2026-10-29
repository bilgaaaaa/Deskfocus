import Foundation

/// A calendar or list one source offers, shown in Settings so it can be switched on or off.
struct TaskContainer: Identifiable, Hashable {
    let source: TaskSourceKind
    /// EventKit calendar identifier, Google calendar id or Google task list id.
    let identifier: String
    let title: String
    /// Account the calendar or list belongs to, e.g. "iCloud" or an email address.
    let accountName: String
    let colorHex: String?

    var id: String { DeskTask.containerKey(source: source, containerIdentifier: identifier) }
}

extension Array where Element == TaskContainer {
    /// Grouped by account, then alphabetically, as Calendar and Reminders list them.
    func sortedForDisplay() -> [TaskContainer] {
        sorted {
            let accountOrder = $0.accountName.localizedCaseInsensitiveCompare($1.accountName)
            if accountOrder != .orderedSame { return accountOrder == .orderedAscending }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}
