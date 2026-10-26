import AppKit
import SwiftUI

/// Searchable list of installed apps with a checkbox each; the selection is saved as bundle ids.
struct BlockedAppsView: View {
    @Environment(AppModel.self) private var model
    @State private var apps: [InstalledApp] = []
    @State private var searchText = ""
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search apps", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                List(filteredApps) { app in
                    Toggle(isOn: blockedBinding(for: app)) {
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text(app.name)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .frame(height: 160)
            }
        }
        .task {
            apps = await InstalledAppCatalog.load()
            isLoading = false
        }
    }

    /// Already blocked apps first so the current choice is easy to review.
    private var filteredApps: [InstalledApp] {
        let blocked = Set(model.snapshot.settings.blockedBundleIds)
        let matching = searchText.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return matching.filter { blocked.contains($0.bundleId) } + matching.filter { !blocked.contains($0.bundleId) }
    }

    private func blockedBinding(for app: InstalledApp) -> Binding<Bool> {
        Binding(
            get: { model.snapshot.settings.blockedBundleIds.contains(app.bundleId) },
            set: { isBlocked in
                model.updateSettings { settings in
                    settings.blockedBundleIds.removeAll { $0 == app.bundleId }
                    if isBlocked { settings.blockedBundleIds.append(app.bundleId) }
                }
                Log.app.info("\(isBlocked ? "Blocked" : "Unblocked", privacy: .public) \(app.bundleId, privacy: .public)")
            }
        )
    }
}
