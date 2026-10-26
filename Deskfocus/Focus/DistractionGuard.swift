import AppKit

/// Keeps chosen apps out of the way during focus, by hiding or quitting them, and toggles the Focus-mode Shortcuts.
@MainActor
final class DistractionGuard {
    private(set) var isActive = false
    private(set) var mode: BlockingMode = .hide

    private var blockedBundleIds: Set<String> = []
    private var focusOffShortcutName = ""
    /// Apps this guard hid, to show again at the end (hide mode).
    private var hiddenBundleIds: Set<String> = []
    /// Apps that were open when focus started and were quit, to reopen at the end (strict mode).
    private var appsToReopen: [String: URL] = [:]
    /// Apps the user already got a "blocked" notification for in this session.
    private var notifiedBundleIds: Set<String> = []
    /// Apps already asked to quit that are still running, e.g. while they show a "save changes?" sheet.
    private var quittingBundleIds: Set<String> = []
    private var observers: [NSObjectProtocol] = []

    func activate(settings: DeskfocusSettings) {
        guard !isActive else { return }
        isActive = true
        mode = settings.blockingMode
        blockedBundleIds = Set(settings.blockedBundleIds)
        focusOffShortcutName = settings.focusOffShortcutName

        for app in NSWorkspace.shared.runningApplications {
            block(app, wasOpenAtStart: true)
        }

        // Catch blocked apps the moment they are opened or switched to.
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                MainActor.assumeIsolated {
                    self?.block(app, wasOpenAtStart: false)
                }
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let bundleId = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier else { return }
            MainActor.assumeIsolated {
                _ = self?.quittingBundleIds.remove(bundleId)
            }
        })

        ShortcutRunner.run(named: settings.focusOnShortcutName)
        Log.distraction.info("Guard on (\(self.mode.rawValue, privacy: .public)), \(self.blockedBundleIds.count) apps blocked")
    }

    /// Brings back what the guard hid or quit and runs the "focus off" Shortcut captured at activation.
    func deactivate() {
        guard isActive else { return }
        isActive = false

        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []

        switch mode {
        case .hide:
            for app in NSWorkspace.shared.runningApplications {
                guard let bundleId = app.bundleIdentifier, hiddenBundleIds.contains(bundleId) else { continue }
                app.unhide()
            }
        case .quit:
            reopenQuitApps()
        }

        ShortcutRunner.run(named: focusOffShortcutName)
        Log.distraction.info("Guard off, restored \(self.hiddenBundleIds.count + self.appsToReopen.count) apps")
        hiddenBundleIds = []
        appsToReopen = [:]
        notifiedBundleIds = []
        quittingBundleIds = []
        blockedBundleIds = []
    }

    private func block(_ app: NSRunningApplication, wasOpenAtStart: Bool) {
        guard isActive,
              let bundleId = app.bundleIdentifier,
              blockedBundleIds.contains(bundleId),
              bundleId != Bundle.main.bundleIdentifier,
              !app.isTerminated else { return }

        switch mode {
        case .hide:
            if app.hide() {
                hiddenBundleIds.insert(bundleId)
                Log.distraction.debug("Hid \(bundleId, privacy: .public)")
            } else if !app.isHidden {
                Log.distraction.error("Could not hide \(bundleId, privacy: .public)")
            }
        case .quit:
            if wasOpenAtStart, let url = app.bundleURL {
                appsToReopen[bundleId] = url
            }
            guard quittingBundleIds.insert(bundleId).inserted else { return }
            if app.terminate() {
                Log.distraction.info("Quit \(bundleId, privacy: .public)")
            } else {
                Log.distraction.error("Could not quit \(bundleId, privacy: .public)")
            }
            // Tell the user once per app why it closed when they open it during focus.
            if !wasOpenAtStart, notifiedBundleIds.insert(bundleId).inserted {
                FocusNotifier.notifyBlocked(appName: app.localizedName ?? bundleId)
            }
        }
    }

    private func reopenQuitApps() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        for (bundleId, url) in appsToReopen {
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    Log.distraction.error("Could not reopen \(bundleId, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}
