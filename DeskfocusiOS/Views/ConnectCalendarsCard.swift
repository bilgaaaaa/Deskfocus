import EventKit
import SwiftUI

/// First-run card on the day page: the list stays empty until Deskfocus may read Calendars or Reminders.
/// Once access was denied iOS no longer asks, so the buttons then open Deskfocus' page in Settings.
struct ConnectCalendarsCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        VStack(alignment: .leading, spacing: 10) {
            Text("Connect your calendars")
                .font(.system(size: 16, weight: .semibold))
            Text("Deskfocus shows today's events and reminders so you can focus on them.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button { allow(status: model.eventKit.calendarStatus) { await model.requestCalendarAccess() } } label: {
                    Label("Calendars", systemImage: "calendar")
                }
                .buttonStyle(DeskfocusPrimaryButtonStyle())
                Button { allow(status: model.eventKit.remindersStatus) { await model.requestRemindersAccess() } } label: {
                    Label("Reminders", systemImage: "checklist")
                }
                .buttonStyle(DeskfocusGlassButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1), in: shape)
        .overlay(shape.strokeBorder(DeskfocusTheme.glassStroke))
    }

    /// Asks iOS when it still can; after a "Don't Allow" only the Settings app can change the answer.
    private func allow(status: EKAuthorizationStatus, request: @escaping () async -> Void) {
        switch status {
        case .denied, .restricted:
            openURL.openAppSettings()
        default:
            Task { await request() }
        }
    }
}
