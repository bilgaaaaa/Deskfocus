import Foundation
import Observation

/// The day or week the user is looking at; fetches the selected week and serves each day's tasks.
@MainActor
@Observable
final class AgendaModel {
    private(set) var selectedDay: Date
    private(set) var isLoading = false

    /// Tasks for `loadedWeek`; today's items always come from the shared snapshot instead.
    private var weekTasks: [DeskTask] = []
    private var loadedWeek: DateInterval?
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
        selectedDay = Calendar.current.startOfDay(for: day)
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
        let today = DateInterval.day(containing: now)
        return Agenda.tasks(weekTasks, on: dayInterval, today: today)
            .filter { !snapshot.completedTaskIds.contains($0.id) }
    }

    /// Forgets the loaded week, e.g. after a sync or a calendar change, and loads it again.
    func reload() async {
        loadedWeek = nil
        await loadIfNeeded()
    }

    private func loadIfNeeded() async {
        let week = selectedWeek
        guard loadedWeek != week else { return }

        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        let result = await repository.fetchTasks(in: week)

        // A newer navigation started while this one loaded; its result wins.
        guard generation == loadGeneration else { return }
        weekTasks = result.tasks
        loadedWeek = week
        isLoading = false
        Log.sync.debug("Loaded \(result.tasks.count) items for the selected week")
    }
}
