import AppKit
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

/// The user's accounts and which of them feed the list; no developer setup is ever shown here.
private struct AccountsSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isConnectingGoogle = false

    /// macOS Internet Accounts, where people add Google, Outlook, Exchange or Yahoo with Apple's own sign-in.
    private static let internetAccountsURL = URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!

    var body: some View {
        Form {
            Section {
                permissionRow(title: "Calendars", isGranted: model.eventKit.hasCalendarAccess) {
                    Task { await model.requestCalendarAccess() }
                }
                permissionRow(title: "Reminders", isGranted: model.eventKit.hasRemindersAccess) {
                    Task { await model.requestRemindersAccess() }
                }
                LabeledContent {
                    Button("Add Account…") { NSWorkspace.shared.open(Self.internetAccountsURL) }
                } label: {
                    Text("Google, Outlook and more")
                    Text("Sign in once in System Settings; their calendars appear here automatically.")
                }
            } header: {
                Text("Your accounts")
            } footer: {
                Text("If access was denied before, allow Deskfocus in System Settings › Privacy & Security.")
            }

            // Only offered when this build can sign in to Google directly.
            if GoogleConfig.isConfigured || model.googleAuth.isConnected {
                Section("Google Tasks") {
                    if model.googleAuth.isConnected {
                        LabeledContent("Connected", value: model.googleAuth.connectedEmail ?? "Google account")
                        Button("Disconnect", role: .destructive) {
                            Task { await model.disconnectGoogle() }
                        }
                    } else {
                        Button(isConnectingGoogle ? String(localized: "Connecting…") : String(localized: "Connect Google Tasks")) {
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
            }

            Section("Show in your list") {
                ForEach(visibleSources, id: \.self) { kind in
                    Toggle(kind.displayName, isOn: model.sourceBinding(kind))
                }
                Toggle("To-dos without a due date", isOn: model.binding(\.includeUndatedTasks))
                    .onChange(of: model.snapshot.settings.includeUndatedTasks) {
                        Task { await model.refresh() }
                    }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(ColorfulSwitchToggleStyle())
    }

    /// Google's own sources only appear once a Google account is connected.
    private var visibleSources: [TaskSourceKind] {
        TaskSourceKind.allCases.filter { !$0.requiresGoogleSignIn || model.googleAuth.isConnected }
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

/// Switch that is clearly green and labelled "On" when enabled, grey and "Off" when not.
struct ColorfulSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            Text(configuration.isOn ? String(localized: "On") : String(localized: "Off"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(configuration.isOn ? Color.green : Color.secondary)
                .frame(minWidth: 24, alignment: .trailing)
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { configuration.isOn.toggle() }
            } label: {
                Capsule()
                    .fill(configuration.isOn ? Color.green : Color.gray.opacity(0.35))
                    .frame(width: 40, height: 24)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                            .padding(2)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(configuration.isOn ? String(localized: "On") : String(localized: "Off"))
        }
        .opacity(configuration.isOn ? 1 : 0.85)
    }
}

/// Timer length, apps to keep away and the Shortcuts that switch the macOS Focus mode.
private struct FocusSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Stepper(value: model.binding(\.focusMinutes), in: DeskfocusSettings.minimumFocusMinutes...DeskfocusSettings.maximumFocusMinutes, step: 5) {
                    LabeledContent("Default for to-dos", value: "\(model.snapshot.settings.focusMinutes) min")
                }
            } header: {
                Text("Focus time")
            } footer: {
                Text("Events focus for their own length. To-dos ask how long when you press ▶ and remember your choice; this default is used from the widget until you pick one.")
            }

            Section {
                Picker("During focus, blocked apps are", selection: model.binding(\.blockingMode)) {
                    ForEach(BlockingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                BlockedAppsView()
            } header: {
                Text("Apps to block while focusing")
            } footer: {
                Text(model.snapshot.settings.blockingMode == .quit
                     ? "Strict: chosen apps are quit when a session starts, quit again if you open them, and reopened when it ends. Apps with unsaved work may ask before closing."
                     : "Chosen apps are hidden when a session starts, hidden again if you switch to them, and shown again when it ends.")
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
            Toggle("Show glass widget on the desktop", isOn: model.binding(\.showDesktopPanel))
            Picker("Widget is", selection: model.binding(\.panelLayout)) {
                Text("Closed (Day)").tag(PanelLayout.day)
                Text("Open (Week)").tag(PanelLayout.week)
            }
            .pickerStyle(.segmented)
            .disabled(!model.snapshot.settings.showDesktopPanel)
            LabeledContent("Glass color") {
                SwatchPicker(
                    options: GlassTint.allCases,
                    selection: model.binding(\.glassTint),
                    color: \.swatch,
                    name: \.displayName
                )
            }
            LabeledContent("Accent") {
                SwatchPicker(
                    options: AccentChoice.allCases,
                    selection: model.binding(\.accentColor),
                    color: \.color,
                    name: \.displayName
                )
            }
            Text("Drag the widget to move it; it stays below your windows on every desktop. Open and close it, or change its colors, from the widget itself too (right-click).")
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
        .toggleStyle(ColorfulSwitchToggleStyle())
    }
}
