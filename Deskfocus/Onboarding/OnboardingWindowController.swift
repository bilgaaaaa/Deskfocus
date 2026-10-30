import AppKit
import SwiftUI

/// Shows the welcome guide in its own window; closing it in any way marks it as seen.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?

    func show(model: AppModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let view = OnboardingView(onFinish: { [weak self] in self?.close() })
            .environment(model)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = String(localized: "Welcome to Deskfocus")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        // Closing early counts as seen too, so the guide never pops up on its own again.
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self, weak model] _ in
            MainActor.assumeIsolated {
                model?.completeOnboarding()
                self?.forgetWindow()
            }
        }

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        Log.app.info("Welcome guide opened")
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
