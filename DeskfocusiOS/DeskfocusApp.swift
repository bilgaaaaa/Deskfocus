import SwiftUI
import UserNotifications

/// iPhone and iPad app: the day or the week in one window, both side by side when there is room, as on the open iPhone Duo.
@main
struct DeskfocusApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Set before launch finishes, so "time is up" also shows while Deskfocus is open.
        UNUserNotificationCenter.current().delegate = FocusNotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(model)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Log.app.info("Back in the foreground, catching up")
            FocusNotifier.requestAuthorizationIfNeeded()
            model.catchUp()
        }
    }
}
