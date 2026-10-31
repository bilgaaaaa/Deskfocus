import Foundation
import Observation
import Sparkle

/// In-app updates through Sparkle: checks the feed on GitHub Releases, then downloads, installs and relaunches in place.
/// Debug builds and builds without a public key never look for updates, so Xcode runs are not replaced.
@MainActor
@Observable
final class AppUpdater {
    /// False when this build cannot update itself; Settings then explains why instead of showing the controls.
    let isAvailable: Bool
    /// Version shown in Settings, e.g. "0.3.0 (3)".
    let currentVersion: String
    /// False while a check or download is already running.
    private(set) var canCheckForUpdates = false

    /// Daily background check; Sparkle stores the choice in the app's user defaults.
    var automaticallyChecksForUpdates: Bool {
        didSet {
            controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            Log.update.info("Automatic update checks set to \(self.automaticallyChecksForUpdates)")
        }
    }

    /// Installs found updates on quit without asking first.
    var automaticallyDownloadsUpdates: Bool {
        didSet {
            controller.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
            Log.update.info("Automatic update installs set to \(self.automaticallyDownloadsUpdates)")
        }
    }

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    /// Sparkle keeps its delegate weakly, so the updater holds it.
    @ObservationIgnored private let delegate: AppUpdaterDelegate
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    init(bundle: Bundle = .main) {
        #if DEBUG
        let isAvailable = false
        #else
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let isAvailable = !publicKey.isEmpty
        #endif

        let delegate = AppUpdaterDelegate()
        let controller = SPUStandardUpdaterController(startingUpdater: isAvailable, updaterDelegate: delegate, userDriverDelegate: nil)

        self.isAvailable = isAvailable
        self.currentVersion = Self.versionString(of: bundle)
        self.delegate = delegate
        self.controller = controller
        self.automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = controller.updater.automaticallyDownloadsUpdates

        guard isAvailable else {
            Log.update.info("Updates are off in this build (debug build or no SUPublicEDKey)")
            return
        }
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            Task { @MainActor in self?.canCheckForUpdates = canCheck }
        }
        Log.update.info("Updater started for Deskfocus \(self.currentVersion, privacy: .public)")
    }

    /// "Check Now" in Settings; Sparkle shows its own window with the result.
    func checkForUpdates() {
        guard isAvailable else { return }
        Log.update.info("Checking for updates on request")
        controller.checkForUpdates(nil)
    }

    private static func versionString(of bundle: Bundle) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// Logs what Sparkle finds and does, so a failed update can be traced in Console.app.
private final class AppUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    /// Sparkle's SUNoUpdateError: also reported as an abort when the app is already up to date.
    private static let noUpdateErrorCode = 1001

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Log.update.info("Update found: \(item.displayVersionString, privacy: .public) (\(item.versionString, privacy: .public))")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Log.update.info("Deskfocus is up to date")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        Log.update.info("Installing update \(item.displayVersionString, privacy: .public)")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        guard !(nsError.domain == SUSparkleErrorDomain && nsError.code == Self.noUpdateErrorCode) else { return }
        Log.update.error("Update stopped: \(error.localizedDescription, privacy: .public)")
    }
}
