import SwiftUI

/// Menu bar app: the panel shows today's list or the running timer; Settings holds accounts and focus options.
@main
struct DeskfocusApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(model)
        } label: {
            // Template version of the app icon; macOS tints it to match the menu bar.
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
