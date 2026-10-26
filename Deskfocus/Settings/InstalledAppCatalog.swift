import Foundation

/// An app the user can choose to block during focus.
struct InstalledApp: Identifiable, Hashable, Sendable {
    let bundleId: String
    let name: String
    let path: String

    var id: String { bundleId }
}

/// Lists apps from the standard Applications folders for the blocked-apps picker.
enum InstalledAppCatalog {
    static func load() async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) {
            scanApplicationFolders()
        }.value
    }

    private static func scanApplicationFolders() -> [InstalledApp] {
        let fileManager = FileManager.default
        let folders = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        let ownBundleId = Bundle.main.bundleIdentifier

        var appsById: [String: InstalledApp] = [:]
        for folder in folders {
            guard let urls = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for url in urls where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleId = bundle.bundleIdentifier,
                      bundleId != ownBundleId,
                      appsById[bundleId] == nil else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                appsById[bundleId] = InstalledApp(bundleId: bundleId, name: name, path: url.path)
            }
        }

        let apps = appsById.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        Log.app.debug("Found \(apps.count) installed apps")
        return apps
    }
}
