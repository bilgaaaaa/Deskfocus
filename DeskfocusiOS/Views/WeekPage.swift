import SwiftUI

/// The selected week as one card per day, like the Mac widget opened up; a day's header opens it on the day page.
struct WeekPage: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AppModel.self) private var model
    let now: Date

    /// Height of the fade at the bottom of the list, so cards slip under the edge instead of being cut off.
    private static let fadeHeight: CGFloat = 18

    var body: some View {
        let agenda = model.agenda
        let week = agenda.selectedWeek

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEEK")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(accent.color)
                    Text(DeskTaskFormatter.weekRange(week))
                        .font(.system(size: 26, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText(countsDown: !agenda.isMovingForward))
                }
                Spacer(minLength: 8)
                PageNavigation(
                    previousLabel: "Previous week",
                    nextLabel: "Next week",
                    onPrevious: { agenda.moveWeek(by: -1) },
                    onNext: { agenda.moveWeek(by: 1) }
                )
            }

            // Alone on the screen the week would hide the session, so it rides above the days;
            // in the two-page spread the day page beside it already shows the ring.
            if horizontalSizeClass != .regular, let session = model.snapshot.focus {
                FocusStrip(session: session, now: now)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    // Old and new week overlap here while one fades out and the other slides in.
                    ZStack(alignment: .top) {
                        VStack(spacing: 10) {
                            ForEach(Agenda.days(in: week), id: \.self) { day in
                                WeekDayCard(
                                    day: day,
                                    tasks: agenda.tasks(on: day, snapshot: model.snapshot, now: now),
                                    isLoaded: agenda.hasLoaded(day, now: now),
                                    now: now
                                )
                                .id(day)
                            }
                        }
                        .id(week)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: agenda.isMovingForward ? 40 : -40)),
                            removal: .opacity
                        ))
                    }
                    .padding(.bottom, Self.fadeHeight)
                }
                .scrollIndicators(.never)
                .refreshable { await model.refresh() }
                .mask { BottomFade(height: Self.fadeHeight) }
                // Opens on the day being viewed, e.g. Saturday further down, instead of always on Monday.
                .onAppear { proxy.scrollTo(agenda.selectedDay, anchor: .top) }
                .onChange(of: week.start) {
                    proxy.scrollTo(agenda.selectedDay, anchor: .top)
                }
            }
        }
    }
}

/// One day of the week page: the header opens the day, and its first items can be started or checked off right here.
private struct WeekDayCard: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(AppModel.self) private var model
    let day: Date
    let tasks: [DeskTask]
    let isLoaded: Bool
    let now: Date

    private let maxItems = 4
    private var isToday: Bool { Calendar.current.isDate(day, inSameDayAs: now) }
    private var isPast: Bool { day < Calendar.current.startOfDay(for: now) }
    private var isSelected: Bool { Calendar.current.isDate(day, inSameDayAs: model.agenda.selectedDay) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        VStack(alignment: .leading, spacing: 6) {
            header

            if !isLoaded {
                LoadingPlaceholder(lineCount: 2, lineHeight: 8)
                    .padding(.vertical, 4)
            } else if tasks.isEmpty {
                Text("Free")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(tasks.prefix(maxItems)) { task in
                    DeskTaskRow(task: task, now: now, resumeRemaining: model.snapshot.savedProgress[task.id]?.remaining) {
                        CompleteTaskButton(task: task, size: 22)
                    } trailing: {
                        HStack(spacing: 4) {
                            EndSessionButton(task: task, size: 30)
                            StartFocusControl(task: task, size: 32)
                        }
                    }
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .move(edge: .trailing))))
                }
                if tasks.count > maxItems {
                    Button("+\(tasks.count - maxItems) more") { model.showDay(day) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(isToday ? 0.12 : 0.06), in: shape)
        .overlay(shape.strokeBorder(isSelected ? accent.color.opacity(0.55) : Color.white.opacity(0.08)))
        .opacity(isPast ? 0.6 : 1)
        .animation(DeskfocusMotion.list, value: tasks.map(\.id))
        .animation(DeskfocusMotion.reveal, value: isLoaded)
    }

    /// Weekday and date; today's date sits in an accent circle, as on the Mac.
    private var header: some View {
        Button {
            withAnimation(DeskfocusMotion.navigate) { model.showDay(day) }
        } label: {
            HStack(spacing: 8) {
                Text(DeskTaskFormatter.shortWeekday(day).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(isToday ? accent.color : .secondary)
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isToday ? accent.onAccent : .primary)
                    .frame(width: 28, height: 28)
                    .background {
                        if isToday {
                            Circle().fill(accent.gradient)
                        }
                    }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DeskfocusPressStyle())
        .accessibilityHint(Text("Open this day"))
    }
}
