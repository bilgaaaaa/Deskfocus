import SwiftUI

/// Settings window: accounts, focus behaviour and general options.
struct SettingsView: View {
    var body: some View {
        TabView {
            AccountsSettingsView()
                .tabItem { Label("Accounts", systemImage: "person.crop.circle") }
            FocusSettingsView()
                .tabItem { Label("Focus", systemImage: "scope") }
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 520, height: 460)
    }
}

/// iCloud permissions, the Google account and which sources feed today's list.
private struct AccountsSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isConnectingGoogle = false

    var body: some View {
        Form {
            Section("iCloud") {
                permissionRow(title: "Calendar", isGranted: model.eventKit.hasCalendarAccess) {
                    Task { await model.requestCalendarAccess() }
                }
                permissionRow(title: "Reminders", isGranted: model.eventKit.hasRemindersAccess) {
                    Task { await model.requestRemindersAccess() }
                }
                Text("If access was denied before, allow Deskfocus in System Settings › Privacy & Security.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Google") {
                if model.googleAuth.isConnected {
                    LabeledContent("Connected", value: model.googleAuth.connectedEmail ?? "Google account")
                    Button("Disconnect", role: .destructive) {
                        Task { await model.disconnectGoogle() }
                    }
                } else if !GoogleConfig.isConfigured {
                    Text("Add your Google OAuth client id to Config/Secrets.xcconfig and rebuild. See README.")
                        .foregroundStyle(.secondary)
                } else {
                    Button(isConnectingGoogle ? "Connecting…" : "Connect Google Calendar & Tasks") {
                        isConnectingGoogle = true
                        Task {
                            await model.connectGoogle()
                            isConnectingGoogle = false
                        }
                    }
                    .disabled(isConnectingGoogle)
                }
                if let message = model.googleErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Show in today's list") {
                ForEach(TaskSourceKind.allCases, id: \.self) { kind in
                    Toggle(kind.displayName, isOn: model.sourceBinding(kind))
                }
                Toggle("Include to-dos without a due date", isOn: model.binding(\.includeUndatedTasks))
                    .onChange(of: model.snapshot.settings.includeUndatedTasks) {
                        Task { await model.refresh() }
                    }
            }
        }
        .formStyle(.grouped)
    }

    private func permissionRow(title: String, isGranted: Bool, request: @escaping () -> Void) -> some View {
        LabeledContent(title) {
            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Allow Access", action: request)
            }
        }
    }
}

/// Timer length, apps to keep away and the Shortcuts that switch the macOS Focus mode.
private struct FocusSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Timer") {
                Stepper(value: model.binding(\.focusMinutes), in: DeskfocusSettings.minimumFocusMinutes...DeskfocusSettings.maximumFocusMinutes, step: 5) {
                    LabeledContent("Focus length", value: "\(model.snapshot.settings.focusMinutes) min")
                }
            }

            Section {
                BlockedAppsView()
            } header: {
                Text("Apps to hide while focusing")
            } footer: {
                Text("Chosen apps are hidden when a session starts, hidden again if you open them, and brought back when it ends.")
            }

            Section {
                TextField("Turn on (e.g. Deskfocus On)", text: model.binding(\.focusOnShortcutName))
                TextField("Turn off (e.g. Deskfocus Off)", text: model.binding(\.focusOffShortcutName))
            } header: {
                Text("Silence notifications with a Focus mode")
            } footer: {
                Text("Create two Shortcuts that turn your \"Deskfocus\" Focus mode on and off, then enter their names here. Choose which apps may notify you in System Settings › Focus.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Toggle("Show glass panel on the desktop", isOn: model.binding(\.showDesktopPanel))
            Text("Drag the panel to move it; it stays below your windows on every desktop.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Open Deskfocus at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    LaunchAtLogin.setEnabled(enabled)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            Text("Keep this on so the timer and app hiding work even when you start focus from the widget.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
