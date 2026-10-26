import AppIntents
import SwiftUI

/// The glass desktop widget: closed it shows the day like the purple widget, open it shows the week.
/// Opening and closing morphs the glass card with a spring while the content cross-fades;
/// starting or ending a session swaps the agenda and the focus ring the same way.
struct DesktopPanelView: View {
    @Environment(AppModel.self) private var model

    static let contentPadding: CGFloat = 20
    static let morphAnimation = Animation.spring(response: 0.45, dampingFraction: 0.86)

    var body: some View {
        let settings = model.snapshot.settings
        let layout = settings.panelLayout
        let cardSize = DesktopPanelController.cardSize(for: layout)
        let shape = RoundedRectangle(cornerRadius: DesktopGlassBackground.cornerRadius, style: .continuous)

        // Ticks every second while a timer runs so the ring moves; every half minute otherwise.
        TimelineView(.periodic(from: .distantPast, by: model.snapshot.focus == nil ? 30 : 1)) { context in
            ZStack(alignment: .topLeading) {
                // Each layout keeps its own final size, so the card reveals it instead of squeezing it.
                content(layout: layout, now: context.date)
                    .frame(
                        width: cardSize.width - Self.contentPadding * 2,
                        height: cardSize.height - Self.contentPadding * 2,
                        alignment: .topLeading
                    )
                    .id(layout)
                    .transition(.opacity)
            }
            .padding(Self.contentPadding)
            .frame(width: cardSize.width, height: cardSize.height, alignment: .topLeading)
            .clipShape(shape)
            // Closed: strong color like the purple widget. Open: light tint so the glass shows.
            .modifier(DesktopGlassBackground(tint: settings.glassTint, intensity: layout == .day ? 0.9 : 0.3))
            .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
            .contextMenu { PanelContextMenu() }
            .padding(DesktopPanelController.shadowInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environment(\.colorScheme, .dark)
            .environment(\.deskfocusAccent, settings.accentColor)
            // The panel is a live view, unlike WidgetKit, so looping animations may run here.
            .environment(\.deskfocusAmbientMotion, true)
            .animation(Self.morphAnimation, value: layout)
            .animation(.easeInOut(duration: 0.3), value: settings.glassTint)
            .animation(DeskfocusMotion.reveal, value: model.snapshot.focus == nil)
        }
    }

    @ViewBuilder
    private func content(layout: PanelLayout, now: Date) -> some View {
        switch layout {
        case .day:
            if let session = model.snapshot.focus {
                FocusSessionView(session: session, now: now, settings: model.snapshot.settings)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            } else {
                DayPanelContent(now: now)
                    .transition(.opacity)
            }
        case .week:
            WeekPanelContent(now: now)
        }
    }
}

/// Right-click menu on the widget: open or close, color, and hide.
private struct PanelContextMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let layout = model.snapshot.settings.panelLayout
        Button(layout == .day ? String(localized: "Open Week") : String(localized: "Close to Day")) {
            model.setPanelLayout(layout == .day ? .week : .day)
        }
        Picker("Color", selection: model.binding(\.glassTint)) {
            ForEach(GlassTint.allCases, id: \.self) { tint in
                Text(tint.displayName).tag(tint)
            }
        }
        Picker("Accent", selection: model.binding(\.accentColor)) {
            ForEach(AccentChoice.allCases, id: \.self) { accent in
                Text(accent.displayName).tag(accent)
            }
        }
        Divider()
        Button("Hide Widget") {
            model.updateSettings { $0.showDesktopPanel = false }
        }
    }
}

/// Closed layout, styled like the purple widget: weekday, big date, progress ring, then the day's items.
/// Day arrows and the open button stay visible at the top right; a new day's list slides in from the side it came from.
private struct DayPanelContent: View {
    @Environment(AppModel.self) private var model
    let now: Date

    /// Height of the fade at the bottom of the list, so rows slip under the edge instead of being cut off.
    private static let fadeHeight: CGFloat = 18

    var body: some View {
        let agenda = model.agenda
        let day = agenda.selectedDay
        let tasks = agenda.tasks(on: day, snapshot: model.snapshot, now: now)
        let isLoaded = agenda.hasLoaded(day, now: now)

        VStack(alignment: .leading, spacing: 14) {
            DayHeaderView(date: day, movesForward: agenda.isMovingForward) {
                VStack(alignment: .trailing, spacing: 10) {
                    PanelNavigation(
                        onPrevious: { agenda.moveDay(by: -1) },
                        onNext: { agenda.moveDay(by: 1) },
                        layout: .day
                    )
                    // Today shows its progress ring; other days offer the way back in the same spot.
                    if agenda.isShowingToday {
                        let done = model.snapshot.completedCount(on: now)
                        DayProgressRing(done: done, total: done + tasks.count)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else {
                        TodayButton(help: "Back to today") { agenda.goToToday() }
                            .transition(.scale(scale: 0.8, anchor: .trailing).combined(with: .opacity))
                    }
                }
            }

            ScrollView {
                // Old and new day overlap here while one fades out and the other slides in.
                ZStack(alignment: .top) {
                    dayList(tasks: tasks, isLoaded: isLoaded)
                        .id(day)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: agenda.isMovingForward ? 28 : -28)),
                            removal: .opacity
                        ))
                }
                .padding(.bottom, Self.fadeHeight)
                .animation(DeskfocusMotion.reveal, value: isLoaded)
            }
            .scrollIndicators(.never)
            .mask { bottomFade }
        }
    }

    @ViewBuilder
    private func dayList(tasks: [DeskTask], isLoaded: Bool) -> some View {
        let agenda = model.agenda
        if !isLoaded {
            LoadingPlaceholder()
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .transition(.opacity)
        } else {
            VStack(spacing: 12) {
                DayAgendaView(
                    tasks: tasks,
                    now: now,
                    maxRows: .max,
                    showsUpNext: agenda.isShowingToday,
                    savedProgress: model.snapshot.savedProgress,
                    completeAction: { task in
                        CompleteTaskButton(task: task)
                    },
                    rowAction: { task in
                        HStack(spacing: 4) {
                            EndSessionButton(task: task)
                            StartFocusControl(task: task)
                        }
                    },
                    upNextAction: { task in
                        HStack(spacing: 6) {
                            EndSessionButton(task: task, size: 32)
                            StartFocusControl(task: task, size: 44, isProminent: true)
                        }
                    }
                )
                // An empty day is an invitation to plan it.
                if tasks.isEmpty {
                    Button { model.showAddTask() } label: {
                        Label("New task", systemImage: "plus")
                    }
                    .buttonStyle(DeskfocusGlassButtonStyle())
                    .transition(.opacity)
                }
            }
            .transition(.opacity)
        }
    }

    private var bottomFade: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.fadeHeight)
        }
    }
}

/// Week layout: header with week arrows, an optional focus strip, then seven day columns.
private struct WeekPanelContent: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(AppModel.self) private var model
    let now: Date

    var body: some View {
        let agenda = model.agenda
        let week = agenda.selectedWeek
        let days = Agenda.days(in: week)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEEK")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(accent.color)
                    Text(DeskTaskFormatter.weekRange(week))
                        .font(.system(size: 26, weight: .bold))
                        .contentTransition(.numericText(countsDown: !agenda.isMovingForward))
                }
                Spacer()
                if !agenda.isShowingThisWeek {
                    TodayButton(help: "Back to this week") { agenda.goToToday() }
                        .padding(.trailing, 8)
                        .transition(.scale(scale: 0.8, anchor: .trailing).combined(with: .opacity))
                }
                PanelNavigation(
                    onPrevious: { agenda.moveWeek(by: -1) },
                    onNext: { agenda.moveWeek(by: 1) },
                    layout: .week
                )
            }

            if let session = model.snapshot.focus {
                FocusStrip(session: session, now: now)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Old and new week overlap here while one fades out and the other slides in.
            ZStack(alignment: .top) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        WeekDayColumn(
                            day: day,
                            tasks: agenda.tasks(on: day, snapshot: model.snapshot, now: now),
                            isLoaded: agenda.hasLoaded(day, now: now),
                            now: now
                        )
                    }
                }
                .id(week.start)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: agenda.isMovingForward ? 40 : -40)),
                    removal: .opacity
                ))
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// One day in the week layout; the header opens that day in the day layout. Past days are dimmed.
private struct WeekDayColumn: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(AppModel.self) private var model
    let day: Date
    let tasks: [DeskTask]
    let isLoaded: Bool
    let now: Date
    @State private var isHeaderHovered = false

    private let maxItems = 6
    private var isToday: Bool { Calendar.current.isDate(day, inSameDayAs: now) }
    private var isPast: Bool { day < Calendar.current.startOfDay(for: now) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        VStack(alignment: .leading, spacing: 8) {
            Button { model.showDay(day) } label: {
                HStack(spacing: 6) {
                    Text(DeskTaskFormatter.shortWeekday(day).uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(isToday ? accent.color : .secondary)
                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isToday ? accent.onAccent : .primary)
                        .frame(width: 24, height: 24)
                        .background {
                            if isToday {
                                Circle().fill(accent.gradient)
                            } else {
                                Circle().fill(Color.white.opacity(isHeaderHovered ? 0.16 : 0))
                            }
                        }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(DeskfocusPressStyle())
            .onHover { hovering in
                withAnimation(DeskfocusMotion.hover) { isHeaderHovered = hovering }
            }
            .help("Open this day")

            VStack(alignment: .leading, spacing: 6) {
                if !isLoaded {
                    LoadingPlaceholder(lineCount: 2, lineHeight: 8)
                } else {
                    ForEach(tasks.prefix(maxItems)) { task in
                        WeekTaskCard(task: task)
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 0.9))))
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
            .animation(DeskfocusMotion.list, value: tasks.map(\.id))
            .animation(DeskfocusMotion.reveal, value: isLoaded)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(isToday ? 0.12 : 0.05), in: shape)
        .overlay {
            if isToday {
                shape.strokeBorder(accent.color.opacity(0.35))
            }
        }
        .opacity(isPast ? 0.6 : 1)
    }
}

/// Compact item in a week column; hovering lights it up and pops in start and done buttons.
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
        // The highlight reaches past the card without moving it out of line with the day header.
        .padding(4)
        .background(Color.white.opacity(isHovered ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(-4)
        .overlay(alignment: .topTrailing) {
            if isHovered {
                TaskActionButtons(task: task, size: 22)
                    .padding(2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.scale(scale: 0.7, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .onHover { hovering in
            withAnimation(DeskfocusMotion.hover) { isHovered = hovering }
        }
    }
}

/// Running session squeezed into one line above the week columns.
private struct FocusStrip: View {
    @Environment(\.deskfocusAccent) private var accent
    let session: FocusSession
    let now: Date

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let progress = 1 - session.remaining(at: now) / max(session.plannedDuration, 1)

        HStack(spacing: 12) {
            FocusRingView(progress: progress, lineWidth: 4)
                .frame(width: 30, height: 30)
                .animation(DeskfocusMotion.ringTick, value: progress)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.taskTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(statusLine)
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(accent.color)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(DeskfocusMotion.digitRoll, value: statusLine)
            }
            Spacer()
            stripControls
        }
        .padding(10)
        .background(accent.color.opacity(0.12), in: shape)
        .overlay(shape.strokeBorder(accent.color.opacity(0.3)))
    }

    private var statusLine: String {
        switch session.phase(at: now) {
        case .running: return String(localized: "\(DeskTaskFormatter.clock(session.remaining(at: now))) left · focusing")
        case .paused(let remaining): return String(localized: "\(DeskTaskFormatter.clock(remaining)) left · paused")
        case .finished: return String(localized: "Time's up")
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
                Button(intent: EndFocusIntent()) { Label("Dismiss", systemImage: "xmark") }
                    .buttonStyle(DeskfocusGlassButtonStyle())
            }
            Button(intent: ExtendFocusIntent()) { Text("+\(FocusController.extensionMinutes) min") }
                .buttonStyle(DeskfocusGlassButtonStyle())
                .help("Add \(FocusController.extensionMinutes) minutes")
            Button(intent: CompleteTaskIntent(taskId: session.taskId)) { Label("Done", systemImage: "checkmark") }
                .buttonStyle(DeskfocusPrimaryButtonStyle())
            if session.phase(at: now) != .finished {
                Button(intent: EndFocusIntent()) { Label("End Session", systemImage: "stop.fill") }
                    .buttonStyle(DeskfocusDangerButtonStyle())
            }
        }
    }
}

/// Pulsing placeholder lines while a week loads, instead of a misleading "All clear" or "Free".
private struct LoadingPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var lineCount = 3
    var lineHeight: CGFloat = 10

    var body: some View {
        Group {
            if reduceMotion {
                lines(isDim: false)
            } else {
                PhaseAnimator([false, true]) { isDim in
                    lines(isDim: isDim)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    /// Ragged right edges, like real titles of different lengths.
    private func lines(isDim: Bool) -> some View {
        VStack(alignment: .leading, spacing: lineHeight) {
            ForEach(0..<lineCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(isDim ? 0.06 : 0.14))
                    .frame(height: lineHeight)
                    .padding(.trailing, CGFloat(index % 3) * 18)
            }
        }
    }
}

/// "Today" pill shown when browsing another day or week; it never wraps or shrinks.
struct TodayButton: View {
    @Environment(\.deskfocusAccent) private var accent
    let help: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(DeskfocusMotion.navigate, action)
        } label: {
            Label("Today", systemImage: "arrow.uturn.backward")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(accent.onAccent)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(accent.gradient, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(DeskfocusPressStyle())
        .fixedSize()
        .help(help)
    }
}

/// New task, ‹ › and the open/close button, shared by both layouts; the arrows animate the move.
struct PanelNavigation: View {
    @Environment(AppModel.self) private var model
    let onPrevious: () -> Void
    let onNext: () -> Void
    let layout: PanelLayout

    var body: some View {
        HStack(spacing: 4) {
            PanelIconButton(systemName: "plus", label: "New task") { model.showAddTask() }
                .padding(.trailing, 4)
            PanelIconButton(systemName: "chevron.left", label: layout == .day ? "Previous day" : "Previous week") {
                withAnimation(DeskfocusMotion.navigate, onPrevious)
            }
            PanelIconButton(systemName: "chevron.right", label: layout == .day ? "Next day" : "Next week") {
                withAnimation(DeskfocusMotion.navigate, onNext)
            }
            PanelIconButton(
                systemName: layout == .day ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                label: layout == .day ? "Open week" : "Close to day",
                isProminent: true
            ) {
                model.setPanelLayout(layout == .day ? .week : .day)
            }
            .padding(.leading, 4)
        }
        .fixedSize()
    }
}

/// Round icon button in the panel header; the prominent one (open/close) uses the accent so it reads differently from the arrows.
private struct PanelIconButton: View {
    @Environment(\.deskfocusAccent) private var accent
    let systemName: String
    let label: LocalizedStringKey
    var isProminent = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isProminent ? accent.onAccent : Color.primary)
                .frame(width: 28, height: 28)
                .background {
                    if isProminent {
                        Circle().fill(accent.gradient)
                    } else {
                        Circle().fill(Color.white.opacity(isHovered ? 0.24 : 0.14))
                    }
                }
                .brightness(isProminent && isHovered ? 0.06 : 0)
                .contentShape(Circle())
        }
        .buttonStyle(DeskfocusPressStyle())
        .onHover { hovering in
            withAnimation(DeskfocusMotion.hover) { isHovered = hovering }
        }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// End, done and start buttons for a task from any day, shown when hovering a week card;
/// the red stop button only appears while the task has time left to resume.
struct TaskActionButtons: View {
    let task: DeskTask
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 4) {
            EndSessionButton(task: task, size: size)
            CompleteTaskButton(task: task, size: size)
            StartFocusControl(task: task, size: size)
        }
    }
}
