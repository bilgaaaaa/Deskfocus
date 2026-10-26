import UserNotifications

/// Sends Deskfocus' own notifications, such as "time is up".
enum FocusNotifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Log.focus.error("Notification permission failed: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.focus.info("Notification permission granted: \(granted)")
            }
        }
    }

    static func notifyFinished(_ session: FocusSession) {
        let content = UNMutableNotificationContent()
        content.title = "Focus time is up"
        content.body = "\(session.taskTitle) — mark it done or start another round."
        content.sound = .default

        post(identifier: session.id.uuidString, content: content)
    }

    /// Explains why a blocked app closed when the user opened it during strict focus.
    static func notifyBlocked(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(appName) is blocked while you focus"
        content.body = "It will reopen when the session ends."

        post(identifier: "blocked-\(appName)", content: content)
    }

    private static func post(identifier: String, content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.focus.error("Could not post notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
