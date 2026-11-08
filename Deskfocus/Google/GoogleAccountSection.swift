import SwiftUI

/// The Google section of Settings on Mac and iPhone: connect or disconnect, ask to reconnect after Google ended
/// the session and, in public builds before Google's verification, "Coming soon" instead of the button.
struct GoogleAccountSection: View {
    @Environment(AppModel.self) private var model
    @State private var isConnecting = false

    var body: some View {
        // Hidden in builds without a client id, unless an account is still connected and needs a way out.
        if GoogleConfig.isConfigured || model.googleAuth.isConnected {
            Section("Google Tasks") {
                if model.googleAuth.isConnected {
                    LabeledContent("Connected", value: model.googleAuth.connectedEmail ?? "Google account")
                    Button("Disconnect", role: .destructive) {
                        Task { await model.disconnectGoogle() }
                    }
                } else if GoogleConfig.isSyncEnabled {
                    if model.googleAuth.sessionExpired {
                        Text("Your Google connection has ended. Connect again to keep seeing your Google tasks and events.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Button(connectTitle) {
                        isConnecting = true
                        Task {
                            await model.connectGoogle()
                            isConnecting = false
                        }
                    }
                    .disabled(isConnecting)
                } else {
                    LabeledContent("Connect Google Tasks") {
                        Text("Coming soon")
                            .foregroundStyle(.secondary)
                    }
                }
                if let message = model.googleErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var connectTitle: String {
        if isConnecting { return String(localized: "Connecting…") }
        return model.googleAuth.sessionExpired ? String(localized: "Reconnect Google Tasks") : String(localized: "Connect Google Tasks")
    }
}
