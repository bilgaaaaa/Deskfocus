import AppKit
import SwiftUI

/// Shows the "New task" form in its own small window, in front of everything, so typing always works.
@MainActor
final class AddTaskWindowController {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    func show(model: AppModel, day: Date) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let view = AddTaskView(
            initialDay: day,
            defaultFocusMinutes: model.snapshot.settings.focusMinutes,
            onClose: { [weak self] in self?.close() }
        )
        .environment(model)

        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = String(localized: "New Task")
        window.styleMask = [.titled, .closable]
        window.level = .floating
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
        Log.app.info("New task window opened")
    }

    private func close() {
        window?.close()
    }

    private func forgetWindow() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        closeObserver = nil
        window = nil
    }
}
