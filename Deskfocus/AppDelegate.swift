import AppKit

/// Owns the app model and handles the launch events SwiftUI scenes don't expose.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.showOnboardingIfNeeded()
    }

    /// Deskfocus has no Dock icon, so opening it again from Finder or Spotlight shows a window instead of doing nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Log.app.info("Deskfocus reopened")
        model.handleReopen()
        return false
    }
}
