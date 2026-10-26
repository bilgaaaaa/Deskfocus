import AppKit

/// Keeps chosen apps out of the way during focus: hides them, re-hides them if opened, and toggles the Focus-mode Shortcuts.
@MainActor
final class DistractionGuard {
    private(set) var isActive = false

    private var blockedBundleIds: Set<String> = []
    private var hiddenBundleIds: Set<String> = []
    private var focusOffShortcutName = ""
    private var activationObserver: NSObjectProtocol?

    func activate(settings: DeskfocusSettings) {
        guard !isActive else { return }
        isActive = true
        blockedBundleIds = Set(settings.blockedBundleIds)
        focusOffShortcutName = settings.focusOffShortcutName
        hiddenBundleIds = []

        for app in NSWorkspace.shared.runningApplications {
            hideIfBlocked(app)
        }

        // Re-hide a blocked app as soon as the user switches to it.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated {
                self?.hideIfBlocked(app)
            }
        }

        ShortcutRunner.run(named: settings.focusOnShortcutName)
        Log.distraction.info("Guard on, \(self.blockedBundleIds.count) apps blocked")
    }

    /// Restores the apps it hid and runs the "focus off" Shortcut captured at activation.
    func deactivate() {
        guard isActive else { return }
        isActive = false

        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil

        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier, hiddenBundleIds.contains(bundleId) else { continue }
            app.unhide()
        }

        ShortcutRunner.run(named: focusOffShortcutName)
        Log.distraction.info("Guard off, restored \(self.hiddenBundleIds.count) apps")
        hiddenBundleIds = []
        blockedBundleIds = []
    }

    private func hideIfBlocked(_ app: NSRunningApplication) {
        guard isActive,
              let bundleId = app.bundleIdentifier,
              blockedBundleIds.contains(bundleId),
              bundleId != Bundle.main.bundleIdentifier else { return }

        if app.hide() {
            hiddenBundleIds.insert(bundleId)
            Log.distraction.debug("Hid \(bundleId, privacy: .public)")
        } else if !app.isHidden {
            Log.distraction.error("Could not hide \(bundleId, privacy: .public)")
        }
    }
}
