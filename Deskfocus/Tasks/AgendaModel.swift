import Foundation
import Observation

/// The day or week the user is looking at; fetches the selected week and serves each day's tasks.
@MainActor
@Observable
final class AgendaModel {
    private(set) var selectedDay: Date
    private(set) var isLoading = false
    /// Direction of the last day or week change, so the panel slides the new content in from that side.
    private(set) var isMovingForward = true

    /// Tasks for `loadedWeek`; today's items always come from the shared snapshot instead.
    private var weekTasks: [DeskTask] = []
    private var loadedWeek: DateInterval?
    /// Week of the load in flight, so coming back to the loaded week doesn't cancel its own reload.
    private var loadingWeek: DateInterval?
    private var loadGeneration = 0
    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
        self.selectedDay = Calendar.current.startOfDay(for: .now)
    }

    var selectedWeek: DateInterval { Agenda.week(containing: selectedDay) }
    var isShowingToday: Bool { Calendar.current.isDateInToday(selectedDay) }
    var isShowingThisWeek: Bool { selectedWeek.contains(.now) }

    // MARK: Navigation

    func select(day: Date) {
        let newDay = Calendar.current.startOfDay(for: day)
        isMovingForward = newDay >= selectedDay
        selectedDay = newDay
        Task { await loadIfNeeded() }
    }

    func moveDay(by offset: Int) {
        guard let day = Calendar.current.date(byAdding: .day, value: offset, to: selectedDay) else { return }
        select(day: day)
    }

    func moveWeek(by offset: Int) {
        guard let day = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: selectedDay) else { return }
        select(day: day)
    }

    func goToToday() {
        select(day: .now)
    }

    // MARK: Data

    /// One day's list: today from the live snapshot, other days from the loaded week, checked-off items hidden.
    func tasks(on day: Date, snapshot: DeskfocusSnapshot, now: Date = .now) -> [DeskTask] {
        let dayInterval = DateInterval.day(containing: day)
        if Calendar.current.isDate(day, inSameDayAs: now) {
            return snapshot.visibleTasks(at: now)
        }
        // While another week is still loading, show nothing rather than the previous week's items.
        guard isLoaded(dayInterval.start) else { return [] }
        let today = DateInterval.day(containing: now)
        return Agenda.tasks(weekTasks, on: dayInterval, today: today)
            .filter { !snapshot.completedTaskIds.contains($0.id) }
    }

    /// False while the week holding this day is still loading; today always comes from the shared snapshot.
    func hasLoaded(_ day: Date, now: Date = .now) -> Bool {
        Calendar.current.isDate(day, inSameDayAs: now) || isLoaded(DateInterval.day(containing: day).start)
    }

    /// Loads the selected week again, e.g. after a sync or a calendar change.
    /// The current items stay on screen meanwhile, so the list doesn't flash empty.
    func reload() async {
        await load(force: true)
    }

    private func loadIfNeeded() async {
        await load(force: false)
    }

    /// The end of a week is the next week's first midnight, so `DateInterval.contains` would count it in.
    private func isLoaded(_ dayStart: Date) -> Bool {
        guard let loadedWeek else { return false }
        return loadedWeek.start <= dayStart && dayStart < loadedWeek.end
    }

    private func load(force: Bool) async {
        let week = selectedWeek
        guard force || loadedWeek != week else {
            // Back on the loaded week: a load still running for another week must not replace it.
            if loadingWeek != week {
                loadGeneration += 1
                loadingWeek = nil
                isLoading = false
            }
            return
        }

        loadGeneration += 1
        let generation = loadGeneration
        loadingWeek = week
        isLoading = true
        let result = await repository.fetchTasks(in: week)

        // A newer navigation started while this one loaded; its result wins.
        guard generation == loadGeneration else { return }
        weekTasks = result.tasks
        loadedWeek = week
        loadingWeek = nil
        isLoading = false
        Log.sync.debug("Loaded \(result.tasks.count) items for the selected week")
    }
}
