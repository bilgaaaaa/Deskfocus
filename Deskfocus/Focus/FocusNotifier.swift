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

        let request = UNNotificationRequest(identifier: session.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.focus.error("Could not post finish notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
