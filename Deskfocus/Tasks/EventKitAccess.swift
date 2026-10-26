import EventKit
import Observation

/// Owns the single EventKit store and the calendar and reminders permissions.
@MainActor
@Observable
final class EventKitAccess {
    let store = EKEventStore()
    private(set) var calendarStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var remindersStatus = EKEventStore.authorizationStatus(for: .reminder)

    var hasCalendarAccess: Bool { calendarStatus == .fullAccess }
    var hasRemindersAccess: Bool { remindersStatus == .fullAccess }

    func requestCalendarAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            Log.sync.info("Calendar access granted: \(granted)")
        } catch {
            Log.sync.error("Calendar access request failed: \(error.localizedDescription, privacy: .public)")
        }
        refreshStatus()
    }

    func requestRemindersAccess() async {
        do {
            let granted = try await store.requestFullAccessToReminders()
            Log.sync.info("Reminders access granted: \(granted)")
        } catch {
            Log.sync.error("Reminders access request failed: \(error.localizedDescription, privacy: .public)")
        }
        refreshStatus()
    }

    func refreshStatus() {
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
    }
}
