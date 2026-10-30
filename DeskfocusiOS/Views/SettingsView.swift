import EventKit
import SwiftUI

/// Settings sheet: accounts and what shows in the list, focus time, colors and language.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                AccountsSection()
                SourcesSection()
                FocusSection()
                LookSection()
                LanguageSection()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toggleStyle(ColorfulSwitchToggleStyle())
        }
    }
}

/// The phone's own calendars and reminders, plus the optional direct Google sign-in; no developer setup is shown here.
private struct AccountsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var isConnectingGoogle = false

    var body: some View {
        Section {
            permissionRow("Calendars", status: model.eventKit.calendarStatus, isGranted: model.eventKit.hasCalendarAccess) {
                await model.requestCalendarAccess()
            }
            permissionRow("Reminders", status: model.eventKit.remindersStatus, isGranted: model.eventKit.hasRemindersAccess) {
                await model.requestRemindersAccess()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Google, Outlook and more")
                Text("Add them once in Settings › Apps › Calendar; their calendars appear here automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Your accounts")
        } footer: {
            Text("If access was denied before, allow Deskfocus in Settings › Privacy & Security.")
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

    /// After a "Don't Allow" iOS no longer asks, so the button opens Deskfocus' page in Settings instead.
    private func permissionRow(_ title: LocalizedStringKey, status: EKAuthorizationStatus, isGranted: Bool, request: @escaping () async -> Void) -> some View {
        LabeledContent(title) {
            if isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Allow Access") {
                    if status == .denied || status == .restricted {
                        openURL.openAppSettings()
                    } else {
                        Task { await request() }
                    }
                }
            }
        }
    }
}

/// Which sources feed the list; Google's own sources only appear once a Google account is connected.
private struct SourcesSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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

    private var visibleSources: [TaskSourceKind] {
        TaskSourceKind.allCases.filter { !$0.requiresGoogleSignIn || model.googleAuth.isConnected }
    }
}

/// Default focus length for to-dos started from the widget before a length was picked.
private struct FocusSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            Stepper(value: model.binding(\.focusMinutes), in: DeskfocusSettings.minimumFocusMinutes...DeskfocusSettings.maximumFocusMinutes, step: 5) {
                LabeledContent("Default for to-dos", value: DeskTaskFormatter.duration(minutes: model.snapshot.settings.focusMinutes))
            }
        } header: {
            Text("Focus time")
        } footer: {
            Text("Events focus for their own length. To-dos ask how long when you press ▶ and remember your choice; this default is used from the widget until you pick one.")
        }
    }
}

/// Glass color behind the app, the widget and the Live Activity, and the accent for buttons and the ring.
private struct LookSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section("Glass color") {
            swatches {
                SwatchPicker(options: GlassTint.allCases, selection: model.binding(\.glassTint), color: \.swatch, name: \.displayName)
            }
        }
        Section("Accent") {
            swatches {
                SwatchPicker(options: AccentChoice.allCases, selection: model.binding(\.accentColor), color: \.color, name: \.displayName)
            }
        }
    }

    /// Swatches scroll sideways on narrow screens, like the closed iPhone Duo, instead of squeezing together.
    private func swatches<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content()
                .padding(.vertical, 4)
        }
    }
}

/// iOS keeps each app's language in Settings, so this opens Deskfocus' page there.
private struct LanguageSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Button {
                openURL.openAppSettings()
            } label: {
                LabeledContent("Language", value: currentLanguageName)
            }
        } footer: {
            Text("Deskfocus uses the language you choose for it in the Settings app.")
        }
    }

    /// The language the app runs in, e.g. "Italiano", named in itself.
    private var currentLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }
}
