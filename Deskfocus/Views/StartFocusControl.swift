import SwiftUI

/// The ▶ button for a task. Timed events, resumable and paused tasks start right away;
/// other to-dos first ask how long to focus, and the choice is remembered for that task.
/// Right-click (a long press on iPhone) offers "Choose length…" to start over with a new length.
struct StartFocusControl: View {
    @Environment(AppModel.self) private var model
    let task: DeskTask
    var size: CGFloat = 28
    var isProminent = false
    @State private var isChoosingLength = false

    /// True when ▶ continues earlier work: saved progress, or the session currently on this task.
    private var resumes: Bool {
        model.snapshot.savedProgress[task.id] != nil || model.snapshot.focus?.taskId == task.id
    }

    private var startsDirectly: Bool {
        let hasOwnLength = task.isEvent && !task.isAllDay && task.startDate != nil && task.endDate != nil
        return hasOwnLength || resumes
    }

    var body: some View {
        Button {
            if startsDirectly {
                model.startFocus(on: task)
            } else {
                isChoosingLength = true
            }
        } label: {
            PlayGlyph(size: size, isProminent: isProminent)
        }
        .buttonStyle(DeskfocusPressStyle())
        .help(resumes ? String(localized: "Resume focus on this task") : String(localized: "Start focus on this task"))
        .contextMenu {
            Button("Choose length…") { isChoosingLength = true }
        }
        .popover(isPresented: $isChoosingLength, arrowEdge: .bottom) {
            FocusLengthPicker(remembered: model.snapshot.taskFocusMinutes[task.id] ?? model.snapshot.settings.focusMinutes) { minutes in
                isChoosingLength = false
                model.startFocus(on: task, minutes: minutes)
            }
            // On iPhone too it stays a small popover by the ▶, instead of turning into a full sheet.
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// Quick focus lengths for a to-do, plus a stepper for any other length.
private struct FocusLengthPicker: View {
    let remembered: Int
    let onPick: (Int) -> Void
    @State private var customMinutes: Int

    init(remembered: Int, onPick: @escaping (Int) -> Void) {
        self.remembered = remembered
        self.onPick = onPick
        _customMinutes = State(initialValue: remembered)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Focus for")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            // One row on the Mac; two where touch buttons are wider than the popover.
            ViewThatFits(in: .horizontal) {
                presetRow(DeskfocusSettings.focusPresets)
                VStack(alignment: .leading, spacing: 6) {
                    presetRow(Array(DeskfocusSettings.focusPresets.prefix(3)))
                    presetRow(Array(DeskfocusSettings.focusPresets.dropFirst(3)))
                }
            }

            HStack {
                Stepper(value: $customMinutes, in: DeskfocusSettings.minimumFocusMinutes...DeskfocusSettings.maximumFocusMinutes, step: 5) {
                    Text("\(customMinutes) min")
                        .monospacedDigit()
                }
                Spacer()
                Button("Start") { onPick(customMinutes) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 330)
    }

    private func presetRow(_ presets: [Int]) -> some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.self) { minutes in
                Button("\(minutes) min") { onPick(minutes) }
                    .buttonStyle(.bordered)
                    .tint(minutes == remembered ? .accentColor : nil)
            }
        }
    }
}
