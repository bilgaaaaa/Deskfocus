import SwiftUI

/// "New task" form: a title, the calendar or list to add it to, and its time.
/// Calendars create events with a start and length; reminder and Google lists create to-dos.
struct AddTaskView: View {
    @Environment(AppModel.self) private var model
    let onClose: () -> Void

    @State private var title = ""
    @State private var targets: [AddTaskTarget] = []
    @State private var selectedTargetId: String?
    @State private var date: Date
    @State private var eventMinutes = 60
    @State private var hasDueDate = true
    @State private var focusMinutes: Int
    @State private var isLoadingTargets = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isTitleFocused: Bool

    init(initialDay: Date, defaultFocusMinutes: Int, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _date = State(initialValue: Self.suggestedStart(on: initialDay))
        _focusMinutes = State(initialValue: defaultFocusMinutes)
    }

    private var selectedTarget: AddTaskTarget? {
        targets.first { $0.id == selectedTargetId }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedTarget != nil && !isSaving
    }

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            form

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onClose)
                    .keyboardShortcut(.cancelAction)
                saveButton
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 16)
        }
        // A grouped Form scrolls and has no natural height, so the window gets a fixed size.
        .frame(width: 440, height: 360)
        .task { await loadTargets() }
        #else
        // A sheet on iPhone: Cancel and Add sit in the bar, which iPhone Duo can move to its side strip.
        NavigationStack {
            form
                .navigationTitle("New Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel, action: onClose)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                }
        }
        .task { await loadTargets() }
        #endif
    }

    private var form: some View {
        Form {
            TextField("Title", text: $title, prompt: Text("What do you want to do?"))
                .focused($isTitleFocused)

            targetPicker

            if let target = selectedTarget {
                if target.createsEvent {
                    DatePicker("Starts", selection: $date)
                    Stepper(value: $eventMinutes, in: 15...480, step: 15) {
                        LabeledContent("Length", value: DeskTaskFormatter.duration(minutes: eventMinutes))
                    }
                } else {
                    Toggle("Due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $date, displayedComponents: .date)
                    }
                    Stepper(value: $focusMinutes, in: DeskfocusSettings.minimumFocusMinutes...DeskfocusSettings.maximumFocusMinutes, step: 5) {
                        LabeledContent("Focus time", value: DeskTaskFormatter.duration(minutes: focusMinutes))
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .toggleStyle(ColorfulSwitchToggleStyle())
    }

    private var saveButton: some View {
        Button(isSaving ? String(localized: "Adding…") : String(localized: "Add")) { save() }
            .disabled(!canSave)
    }

    /// Where to allow access: the Mac's Calendars tab, or the iPhone's Settings sheet, which has no such tab.
    private var noAccessHint: LocalizedStringKey {
        #if os(macOS)
        "Allow Calendars or Reminders in Settings › Calendars first."
        #else
        "Allow Calendars or Reminders in Settings first."
        #endif
    }

    @ViewBuilder
    private var targetPicker: some View {
        if isLoadingTargets {
            LabeledContent("Add to") { ProgressView().controlSize(.small) }
        } else if targets.isEmpty {
            LabeledContent("Add to") {
                Text(noAccessHint)
                    .foregroundStyle(.secondary)
            }
        } else {
            Picker("Add to", selection: $selectedTargetId) {
                targetSection("Calendars", kind: .event)
                targetSection("Reminders", kind: .reminder)
                targetSection("Google Tasks", kind: .googleTask)
            }
        }
    }

    @ViewBuilder
    private func targetSection(_ header: LocalizedStringKey, kind: AddTaskTarget.Kind) -> some View {
        let items = targets.filter { $0.kind == kind }
        if !items.isEmpty {
            Section(header) {
                ForEach(items) { target in
                    Text(verbatim: "\(target.title) · \(target.accountName)")
                        .tag(Optional(target.id))
                }
            }
        }
    }

    private func loadTargets() async {
        targets = await model.taskCreator.targets()
        let remembered = model.snapshot.settings.lastAddTargetId
        selectedTargetId = targets.contains { $0.id == remembered } ? remembered : targets.first?.id
        isLoadingTargets = false
        isTitleFocused = true
    }

    private func save() {
        guard let target = selectedTarget else { return }
        let draft = NewTaskDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            target: target,
            date: date,
            eventMinutes: eventMinutes,
            hasDueDate: hasDueDate,
            focusMinutes: focusMinutes
        )
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await model.createTask(draft)
                onClose()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    /// Next :00 or :30 today (kept on today even late at night), or 9:00 on another day.
    private static func suggestedStart(on day: Date, now: Date = .now) -> Date {
        let calendar = Calendar.current
        guard calendar.isDate(day, inSameDayAs: now) else {
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        }
        let minute = calendar.component(.minute, from: now)
        let next = calendar.date(byAdding: .minute, value: minute < 30 ? 30 - minute : 60 - minute, to: now) ?? now
        let candidate = next.isOnSameDay(as: now, in: calendar) ? next : now
        return calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate)) ?? candidate
    }
}

private extension Date {
    func isOnSameDay(as other: Date, in calendar: Calendar) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }
}
