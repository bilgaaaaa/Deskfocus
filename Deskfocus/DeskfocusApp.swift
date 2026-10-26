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
            MenuBarLabel(session: model.snapshot.focus)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

/// Menu bar icon: a timer while focusing, a checklist otherwise.
private struct MenuBarLabel: View {
    let session: FocusSession?

    var body: some View {
        if let session, session.status != .finished {
            Image(systemName: "timer")
        } else {
            Image(systemName: "checklist")
        }
    }
}
