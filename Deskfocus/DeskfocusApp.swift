import SwiftUI

/// Menu bar app: the panel shows today's list or the running timer; Settings and the welcome guide open in their own windows.
@main
struct DeskfocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appDelegate.model)
        } label: {
            // Template version of the app icon; macOS tints it to match the menu bar.
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)
    }
}
