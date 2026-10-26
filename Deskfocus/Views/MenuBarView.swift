import AppIntents
import AppKit
import SwiftUI

/// Menu bar popover: the selected day with arrows, a focus banner while a session runs, and sync status.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .distantPast, by: model.snapshot.focus == nil ? 30 : 1)) { context in
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                if let session = model.snapshot.focus {
                    FocusBanner(session: session, now: context.date)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }

                if let message = model.repository.lastErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }

                taskList(now: context.date)

                Divider()
                footer
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .frame(width: 340)
            .environment(\.deskfocusAccent, model.snapshot.settings.accentColor)
        }
    }

    private var header: some View {
        let agenda = model.agenda
        return HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(agenda.isShowingToday ? "Today" : DeskTaskFormatter.weekday(agenda.selectedDay))
                    .font(.system(size: 15, weight: .bold))
                Text(DeskTaskFormatter.dayMonth(agenda.selectedDay))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !agenda.isShowingToday {
                Button("Today") { agenda.goToToday() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            Button { agenda.moveDay(by: -1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
                .help("Previous day")
            Button { agenda.moveDay(by: 1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
                .help("Next day")
        }
    }

    private func taskList(now: Date) -> some View {
        let tasks = model.agenda.tasks(on: model.agenda.selectedDay, snapshot: model.snapshot, now: now)

        return Group {
            if tasks.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(tasks) { task in
                            MenuTaskRow(task: task, now: now)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 340)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 2) {
            if model.repository.isSyncing || model.agenda.isLoading {
                ProgressView().controlSize(.small)
            } else if let lastSync = model.snapshot.lastSyncDate {
                Text("Updated \(lastSync, style: .relative) ago")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            footerButton("arrow.clockwise", help: "Refresh") {
                Task { await model.refresh() }
            }
            .disabled(model.repository.isSyncing)

            SettingsLink {
                Image(systemName: "gearshape")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .simultaneousGesture(TapGesture().onEnded { NSApp.activate() })

            footerButton("power", help: "Quit Deskfocus") {
                NSApp.terminate(nil)
            }
        }
    }

    private func footerButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private var emptyMessage: String {
        let hasAccess = model.eventKit.hasCalendarAccess || model.eventKit.hasRemindersAccess || model.googleAuth.isConnected
        return hasAccess ? "Nothing planned for this day." : "Connect your calendars in Settings to see your tasks."
    }
}

/// Popover row: round checkbox to complete, start button highlighted on hover.
private struct MenuTaskRow: View {
    @Environment(AppModel.self) private var model
    let task: DeskTask
    let now: Date
    @State private var isHovered = false

    var body: some View {
        DeskTaskRow(task: task, now: now) {
            Button { model.complete(task) } label: {
                Circle()
                    .strokeBorder(Color.secondary, lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Mark as done")
        } trailing: {
            Button { model.startFocus(on: task) } label: { PlayGlyph(size: 28, isProminent: isHovered) }
                .buttonStyle(.plain)
                .help("Start focus on this task")
        }
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(isHovered ? 0.07 : 0), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { isHovered = $0 }
    }
}

/// Compact running-session card at the top of the popover.
private struct FocusBanner: View {
    @Environment(\.deskfocusAccent) private var accent
    let session: FocusSession
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            FocusRingView(progress: 1 - session.remaining(at: now) / max(session.plannedDuration, 1), lineWidth: 4)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.taskTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(statusLine)
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(accent.colors.deep)
            }

            Spacer(minLength: 4)

            controls
        }
        .padding(10)
        .background(accent.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(accent.color.opacity(0.35)))
    }

    private var statusLine: String {
        switch session.phase(at: now) {
        case .running: return "\(DeskTaskFormatter.clock(session.remaining(at: now))) left · focusing"
        case .paused(let remaining): return "\(DeskTaskFormatter.clock(remaining)) left · paused"
        case .finished: return "Time's up"
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 4) {
            switch session.phase(at: now) {
            case .running:
                iconButton("pause.fill", help: "Pause", intent: PauseFocusIntent())
            case .paused:
                iconButton("play.fill", help: "Resume", intent: ResumeFocusIntent())
            case .finished:
                iconButton("arrow.clockwise", help: "Another round", intent: StartFocusIntent(taskId: session.taskId))
            }
            iconButton("checkmark", help: "Done", intent: CompleteTaskIntent(taskId: session.taskId))
            iconButton("xmark", help: session.phase(at: now) == .finished ? "Dismiss" : "End session", intent: StopFocusIntent())
        }
    }

    private func iconButton(_ systemName: String, help: String, intent: some AppIntent) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 26, height: 26)
                .background(Color.primary.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
