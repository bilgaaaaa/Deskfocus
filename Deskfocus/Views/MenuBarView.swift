import AppKit
import SwiftUI

/// Menu bar panel: the focus session when one exists, otherwise today's list; sync status and settings at the bottom.
struct MenuBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session = model.snapshot.focus {
                FocusPanelView(session: session)
                Divider()
            }

            taskList

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    private var taskList: some View {
        let tasks = model.snapshot.visibleTasks(at: .now)

        return VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.title3.weight(.semibold))

            if let message = model.repository.lastErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if tasks.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(tasks) { task in
                            TaskRowView(
                                task: task,
                                onStart: { model.startFocus(on: task) },
                                onComplete: { model.complete(taskId: task.id) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }

    private var footer: some View {
        HStack {
            if model.repository.isSyncing {
                ProgressView().controlSize(.small)
            } else if let lastSync = model.snapshot.lastSyncDate {
                Text("Updated \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
            .disabled(model.repository.isSyncing)

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .simultaneousGesture(TapGesture().onEnded { NSApp.activate() })

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit Deskfocus")
        }
    }

    private var emptyMessage: String {
        let hasAccess = model.eventKit.hasCalendarAccess || model.eventKit.hasRemindersAccess || model.googleAuth.isConnected
        return hasAccess ? "All clear for today." : "Connect your calendars in Settings to see today's tasks."
    }
}
