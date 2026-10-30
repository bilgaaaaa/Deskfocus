import SwiftUI

/// One day, styled like the Mac widget: weekday, big date, ‹ › and today's progress ring, then "Up next" and the rest.
/// While a focus session exists its ring takes the page, as on the widget.
struct DayPage: View {
    @Environment(AppModel.self) private var model
    let now: Date

    var body: some View {
        if let session = model.snapshot.focus {
            FocusSessionView(session: session, now: now, settings: model.snapshot.settings)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
        } else {
            DayAgendaPage(now: now)
                .transition(.opacity)
        }
    }
}

/// The day's header and list; a new day slides in from the side it came from, and pulling down syncs.
private struct DayAgendaPage: View {
    @Environment(AppModel.self) private var model
    let now: Date

    /// Height of the fade at the bottom of the list, so rows slip under the edge instead of being cut off.
    private static let fadeHeight: CGFloat = 18

    /// False until Deskfocus may read Calendars, Reminders or Google, when the list could only ever be empty.
    private var hasAnySource: Bool {
        model.eventKit.hasCalendarAccess || model.eventKit.hasRemindersAccess || model.googleAuth.isConnected
    }

    var body: some View {
        let agenda = model.agenda
        let day = agenda.selectedDay
        let tasks = agenda.tasks(on: day, snapshot: model.snapshot, now: now)
        let isLoaded = agenda.hasLoaded(day, now: now)

        VStack(alignment: .leading, spacing: 14) {
            DayHeaderView(date: day, movesForward: agenda.isMovingForward) {
                VStack(alignment: .trailing, spacing: 10) {
                    PageNavigation(
                        previousLabel: "Previous day",
                        nextLabel: "Next day",
                        onPrevious: { agenda.moveDay(by: -1) },
                        onNext: { agenda.moveDay(by: 1) }
                    )
                    // Only today has a ring; "Today" in the bar leads back from other days.
                    if agenda.isShowingToday {
                        let done = model.snapshot.completedCount(on: now)
                        DayProgressRing(done: done, total: done + tasks.count)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
            }

            if let message = model.repository.lastErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if hasAnySource {
                        // Old and new day overlap here while one fades out and the other slides in.
                        ZStack(alignment: .top) {
                            dayList(tasks: tasks, isLoaded: isLoaded)
                                .id(day)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(x: agenda.isMovingForward ? 28 : -28)),
                                    removal: .opacity
                                ))
                        }
                        .animation(DeskfocusMotion.reveal, value: isLoaded)
                    } else {
                        ConnectCalendarsCard()
                    }
                }
                .padding(.bottom, Self.fadeHeight)
            }
            .scrollIndicators(.never)
            .refreshable { await model.refresh() }
            .mask { BottomFade(height: Self.fadeHeight) }
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
                        CompleteTaskButton(task: task, size: 24)
                    },
                    rowAction: { task in
                        HStack(spacing: 6) {
                            EndSessionButton(task: task, size: 32)
                            StartFocusControl(task: task, size: 36)
                        }
                    },
                    upNextAction: { task in
                        HStack(spacing: 8) {
                            EndSessionButton(task: task, size: 36)
                            StartFocusControl(task: task, size: 50, isProminent: true)
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
}
