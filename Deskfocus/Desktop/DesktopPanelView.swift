import AppIntents
import SwiftUI

/// Content of the glass desktop panel: the day or week agenda, or the focus session while one runs.
struct DesktopPanelView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // Ticks every second while a timer runs so the ring moves; every half minute otherwise.
        TimelineView(.periodic(from: .now, by: model.snapshot.focus == nil ? 30 : 1)) { context in
            content(now: context.date)
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .modifier(DesktopGlassBackground())
                .environment(\.colorScheme, .dark)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        switch model.snapshot.settings.panelLayout {
        case .day:
            if let session = model.snapshot.focus {
                FocusSessionView(session: session, now: now, settings: model.snapshot.settings)
            } else {
                DayPanelContent(now: now)
            }
        case .week:
            WeekPanelContent(now: now)
        }
    }
}

/// Day layout: header with arrows, then the selected day's list with an "Up next" card on today.
private struct DayPanelContent: View {
    @Environment(AppModel.self) private var model
    let now: Date

    var body: some View {
        let agenda = model.agenda
        let tasks = agenda.tasks(on: agenda.selectedDay, snapshot: model.snapshot, now: now)

        VStack(alignment: .leading, spacing: 12) {
            DayHeaderView(date: agenda.selectedDay) {
                PanelNavigation(
                    onPrevious: { agenda.moveDay(by: -1) },
                    onNext: { agenda.moveDay(by: 1) },
                    onToday: agenda.isShowingToday ? nil : { agenda.goToToday() },
                    layout: .day
                )
            }

            if agenda.isShowingToday {
                let done = model.snapshot.completedCount(on: now)
                ProgressView(value: Double(done), total: Double(max(done + tasks.count, 1)))
                    .tint(DeskfocusTheme.amber)
                    .accessibilityLabel("\(done) of \(done + tasks.count) done today")
            }

            ScrollView {
                DayAgendaView(
                    tasks: tasks,
                    now: now,
                    maxRows: .max,
                    showsUpNext: agenda.isShowingToday,
                    rowAction: { task in
                        TaskActionButtons(task: task)
                    },
                    upNextAction: { task in
                        Button { model.startFocus(on: task) } label: { PlayGlyph(size: 40, isProminent: true) }
                            .buttonStyle(.plain)
                            .help("Start focus on this task")
                    }
                )
            }
            .scrollIndicators(.never)
        }
    }
}

/// Week layout: header with week arrows, an optional focus strip, then seven day columns.
private struct WeekPanelContent: View {
    @Environment(AppModel.self) private var model
    let now: Date

    var body: some View {
        let agenda = model.agenda
        let days = Agenda.days(in: agenda.selectedWeek)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEEK")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(DeskfocusTheme.amber)
                    Text(DeskTaskFormatter.weekRange(agenda.selectedWeek))
                        .font(.system(size: 26, weight: .bold))
                }
                Spacer()
                PanelNavigation(
                    onPrevious: { agenda.moveWeek(by: -1) },
                    onNext: { agenda.moveWeek(by: 1) },
                    onToday: agenda.isShowingThisWeek ? nil : { agenda.goToToday() },
                    layout: .week
                )
            }

            if let session = model.snapshot.focus {
                FocusStrip(session: session, now: now)
            }

            HStack(alignment: .top, spacing: 8) {
                ForEach(days, id: \.self) { day in
                    WeekDayColumn(day: day, tasks: agenda.tasks(on: day, snapshot: model.snapshot, now: now), now: now)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// One day in the week layout; the header opens that day in the day layout.
private struct WeekDayColumn: View {
    @Environment(AppModel.self) private var model
    let day: Date
    let tasks: [DeskTask]
    let now: Date

    private let maxItems = 6
    private var isToday: Bool { Calendar.current.isDate(day, inSameDayAs: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { model.showDay(day) } label: {
                HStack(spacing: 6) {
                    Text(DeskTaskFormatter.shortWeekday(day).uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(isToday ? DeskfocusTheme.amber : .secondary)
                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isToday ? DeskfocusTheme.ink : .primary)
                        .frame(width: 24, height: 24)
                        .background {
                            if isToday { Circle().fill(DeskfocusTheme.focusGradient) }
                        }
                }
            }
            .buttonStyle(.plain)
            .help("Open this day")

            VStack(alignment: .leading, spacing: 6) {
                ForEach(tasks.prefix(maxItems)) { task in
                    WeekTaskCard(task: task)
                }
                if tasks.count > maxItems {
                    Button("+\(tasks.count - maxItems) more") { model.showDay(day) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if tasks.isEmpty {
                    Text("Free")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(isToday ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Compact item in a week column; hovering shows start and done buttons.
private struct WeekTaskCard: View {
    let task: DeskTask
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Capsule()
                .fill(Color(hex: task.colorHex) ?? DeskfocusTheme.indigo)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                if let time = DeskTaskFormatter.startTime(for: task) {
                    Text(time)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(task.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .topTrailing) {
            if isHovered {
                TaskActionButtons(task: task, size: 22)
                    .padding(2)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .onHover { isHovered = $0 }
    }
}

/// Running session squeezed into one line above the week columns.
private struct FocusStrip: View {
    let session: FocusSession
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            FocusRingView(progress: 1 - session.remaining(at: now) / max(session.plannedDuration, 1), lineWidth: 4)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.taskTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(statusLine)
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(DeskfocusTheme.amber)
            }
            Spacer()
            stripControls
        }
        .padding(10)
        .background(DeskfocusTheme.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(DeskfocusTheme.amber.opacity(0.3)))
    }

    private var statusLine: String {
        switch session.phase(at: now) {
        case .running: return "\(DeskTaskFormatter.clock(session.remaining(at: now))) left · focusing"
        case .paused(let remaining): return "\(DeskTaskFormatter.clock(remaining)) left · paused"
        case .finished: return "Time's up"
        }
    }

    @ViewBuilder
    private var stripControls: some View {
        HStack(spacing: 8) {
            switch session.phase(at: now) {
            case .running:
                Button(intent: PauseFocusIntent()) { Label("Pause", systemImage: "pause.fill") }
                    .buttonStyle(DeskfocusGlassButtonStyle())
            case .paused:
                Button(intent: ResumeFocusIntent()) { Label("Resume", systemImage: "play.fill") }
                    .buttonStyle(DeskfocusGlassButtonStyle())
            case .finished:
                Button(intent: StopFocusIntent()) { Label("Dismiss", systemImage: "xmark") }
                    .buttonStyle(DeskfocusGlassButtonStyle())
            }
            Button(intent: CompleteTaskIntent(taskId: session.taskId)) { Label("Done", systemImage: "checkmark") }
                .buttonStyle(DeskfocusPrimaryButtonStyle())
        }
    }
}

/// ‹ Today › controls plus the day/week switch, shared by both layouts.
struct PanelNavigation: View {
    @Environment(AppModel.self) private var model
    let onPrevious: () -> Void
    let onNext: () -> Void
    /// Nil when already showing the current day or week.
    let onToday: (() -> Void)?
    let layout: PanelLayout

    var body: some View {
        HStack(spacing: 4) {
            if let onToday {
                Button("Today", action: onToday)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(DeskfocusTheme.amber)
                    .padding(.trailing, 4)
            }
            iconButton("chevron.left", label: layout == .day ? "Previous day" : "Previous week", action: onPrevious)
            iconButton("chevron.right", label: layout == .day ? "Next day" : "Next week", action: onNext)
            iconButton(
                layout == .day ? "rectangle.split.3x1" : "list.bullet",
                label: layout == .day ? "Show week" : "Show day",
                action: { model.setPanelLayout(layout == .day ? .week : .day) }
            )
        }
    }

    private func iconButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Done and start buttons for a task from any day, used in rows and on hover.
struct TaskActionButtons: View {
    @Environment(AppModel.self) private var model
    let task: DeskTask
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 4) {
            Button { model.complete(task) } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .frame(width: size, height: size)
                    .background(Color.primary.opacity(0.1), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Mark as done")

            Button { model.startFocus(on: task) } label: { PlayGlyph(size: size) }
                .buttonStyle(.plain)
                .help("Start focus on this task")
        }
    }
}
