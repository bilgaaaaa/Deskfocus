import AppKit
import EventKit
import SwiftUI

/// Settings window: calendars, focus behaviour and general options.
struct SettingsView: View {
    var body: some View {
        TabView {
            CalendarsSettingsView()
                .tabItem { Label("Calendars", systemImage: "calendar") }
            FocusSettingsView()
                .tabItem { Label("Focus", systemImage: "scope") }
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 540, height: 560)
    }
}

/// Access to Calendar and Reminders, other accounts and Google Tasks; shared by Settings and the welcome guide.
/// No developer setup is ever shown here.
struct CalendarAccountsSection: View {
    @Environment(AppModel.self) private var model
    @State private var isConnectingGoogle = false

    /// macOS Internet Accounts, where people add Google, Outlook, Exchange or Yahoo with Apple's own sign-in.
    private static let internetAccountsURL = URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!

    var body: some View {
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
    }

    private func permissionRow(title: LocalizedStringKey, isGranted: Bool, request: @escaping () -> Void) -> some View {
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

/// Accounts first, then every connected source with a switch for each of its calendars or lists.
private struct CalendarsSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var containers: [TaskContainer] = []
    @State private var isLoadingContainers = true

    var body: some View {
        Form {
            CalendarAccountsSection()

            ForEach(availableSources, id: \.self) { kind in
                sourceSection(kind)
            }

            Section("Options") {
                Toggle("To-dos without a due date", isOn: model.binding(\.includeUndatedTasks))
                    .onChange(of: model.snapshot.settings.includeUndatedTasks) {
                        Task { await model.refresh() }
                    }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(ColorfulSwitchToggleStyle())
        // Reloads when access is granted or a Google account is connected or removed.
        .task(id: accessState) { await loadContainers() }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            Task { await loadContainers() }
        }
    }

    /// Sources the user can already read from; the others are set up in "Your accounts" above.
    private var availableSources: [TaskSourceKind] {
        TaskSourceKind.allCases.filter { model.repository.isAvailable($0) }
    }

    private var accessState: [Bool] {
        [model.eventKit.hasCalendarAccess, model.eventKit.hasRemindersAccess, model.googleAuth.isConnected]
    }

    @ViewBuilder
    private func sourceSection(_ kind: TaskSourceKind) -> some View {
        let isSourceOn = model.snapshot.settings.enabledSources.contains(kind)
        let items = containers.filter { $0.source == kind }

        Section {
            Toggle("Show in Deskfocus", isOn: model.sourceBinding(kind))
            if isSourceOn {
                if items.isEmpty && isLoadingContainers {
                    LabeledContent("Loading…") { ProgressView().controlSize(.small) }
                } else if items.isEmpty {
                    Text("Nothing to show yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { container in
                        Toggle(isOn: model.containerBinding(container)) {
                            TaskContainerLabel(container: container)
                        }
                    }
                }
            }
        } header: {
            Text(kind.displayName)
        } footer: {
            if kind == .appleCalendar {
                Text("Includes the accounts added in System Settings, such as Google or Outlook. Switch off the calendars you don't need.")
            }
        }
    }

    private func loadContainers() async {
        isLoadingContainers = true
        containers = await model.repository.containers()
        isLoadingContainers = false
    }
}

/// Calendar color, name and account, as macOS Calendar shows them.
private struct TaskContainerLabel: View {
    let container: TaskContainer

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: container.colorHex) ?? DeskfocusTheme.indigo)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: container.title)
                Text(verbatim: container.accountName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

/// Language, the desktop widget's look and position, and startup.
private struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: Binding(
                    get: { model.snapshot.settings.language },
                    set: { model.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(verbatim: language.displayName).tag(language)
                    }
                }
                if model.snapshot.settings.language != model.launchLanguage {
                    HStack {
                        Text("Restart Deskfocus to switch language.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Now") { model.relaunch() }
                            .buttonStyle(DeskfocusPrimaryButtonStyle())
                    }
                }
            } footer: {
                Text("Widgets added from the widget gallery switch within a few minutes.")
            }

            Section {
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
                LabeledContent("Position") {
                    Button("Reset Widget Position") { model.resetDesktopPanelPosition() }
                }
            } header: {
                Text("Desktop widget")
            } footer: {
                Text("Drag the widget to move it; it stays below your windows on every desktop. Open and close it, or change its colors, from the widget itself too (right-click).")
            }

            Section {
                Toggle("Open Deskfocus at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLogin.setEnabled(enabled)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                LabeledContent("Welcome guide") {
                    Button("Show Again") { model.showOnboarding() }
                }
            } header: {
                Text("Startup")
            } footer: {
                Text("Keep this on so the timer and app hiding work even when you start focus from the widget.")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(ColorfulSwitchToggleStyle())
    }
}
