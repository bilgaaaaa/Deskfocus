import AppKit
import SwiftUI

/// Shows Settings in its own window, so it opens the same way from the menu bar, the desktop widget and the welcome guide.
/// SwiftUI's `Settings` scene can only be opened from inside a SwiftUI scene, which the desktop widget is not.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    func show(model: AppModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let view = SettingsView().environment(model)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = String(localized: "Deskfocus Settings")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        // Forget the window once it closes, whichever way it was closed.
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.forgetWindow()
            }
        }

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        Log.app.info("Settings window opened")
    }

    private func forgetWindow() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        closeObserver = nil
        window = nil
    }
}
