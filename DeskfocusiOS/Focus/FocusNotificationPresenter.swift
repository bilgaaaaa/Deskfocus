import UserNotifications

/// Shows "time is up" as a banner with sound even while Deskfocus is open, since the phone often lies face up on the desk.
final class FocusNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = FocusNotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Log.focus.debug("Showing a notification while the app is open")
        return [.banner, .list, .sound]
    }
}
