import UserNotifications

/// Sends Deskfocus' own notifications, such as "time is up".
enum FocusNotifier {
    /// The scheduled "time is up" alert on iPhone; there is only ever one, so scheduling again replaces it.
    private static let scheduledFinishIdentifier = "deskfocus.focus.finished"

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Log.focus.error("Notification permission failed: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.focus.info("Notification permission granted: \(granted)")
            }
        }
    }

    /// Asks only while there is no answer yet, so the iPhone app can call it every time it comes to the front,
    /// in case its first launch was in the background for a widget button, when iOS cannot ask.
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            requestAuthorization()
        }
    }

    /// Posts "time is up" now; the Mac app calls it when its end timer fires.
    static func notifyFinished(_ session: FocusSession) {
        post(identifier: session.id.uuidString, content: finishedContent(for: session), trigger: nil)
    }

    /// Schedules "time is up" for the session's end, because iOS suspends the app long before a timer of its own could fire.
    static func scheduleFinished(_ session: FocusSession, at endDate: Date, now: Date = .now) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, endDate.timeIntervalSince(now)), repeats: false)
        post(identifier: scheduledFinishIdentifier, content: finishedContent(for: session), trigger: trigger)
        Log.focus.debug("Time-is-up alert scheduled")
    }

    /// Withdraws the scheduled alert, e.g. when the session is paused, ended or completed early.
    static func cancelScheduledFinish() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [scheduledFinishIdentifier])
        Log.focus.debug("Time-is-up alert cancelled")
    }

    /// Explains why a blocked app closed when the user opened it during strict focus.
    static func notifyBlocked(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(appName) is blocked while you focus")
        content.body = String(localized: "It will reopen when the session ends.")

        post(identifier: "blocked-\(appName)", content: content, trigger: nil)
    }

    private static func finishedContent(for session: FocusSession) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Focus time is up")
        content.body = String(localized: "\(session.taskTitle) — mark it done or start another round.")
        content.sound = .default
        return content
    }

    private static func post(identifier: String, content: UNMutableNotificationContent, trigger: UNNotificationTrigger?) {
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.focus.error("Could not post notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
