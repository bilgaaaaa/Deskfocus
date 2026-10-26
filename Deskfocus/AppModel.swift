import AppKit
import EventKit
import Observation
import SwiftUI
import WidgetKit

/// Root of the app: owns the services, keeps them in sync with the shared state and exposes actions to the views.
@MainActor
@Observable
final class AppModel {
    let eventKit: EventKitAccess
    let googleAuth: GoogleAuthService
    let repository: TaskRepository
    let agenda: AgendaModel
    let taskCreator: TaskCreationService
    let focus: FocusCoordinator

    private(set) var snapshot: DeskfocusSnapshot
    var googleErrorMessage: String?

    private static let refreshInterval: TimeInterval = 5 * 60

    private let desktopPanel = DesktopPanelController()
    private let addTaskWindow = AddTaskWindowController()
    @ObservationIgnored private var stateObserver: DarwinObserver?
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []

    init() {
        let eventKit = EventKitAccess()
        let googleAuth = GoogleAuthService()
        let googleClient = GoogleAPIClient(auth: googleAuth)
        let repository = TaskRepository(sources: [
            AppleCalendarSource(access: eventKit),
            AppleRemindersSource(access: eventKit),
            GoogleCalendarSource(auth: googleAuth, client: googleClient),
            GoogleTasksSource(auth: googleAuth, client: googleClient)
        ])

        self.eventKit = eventKit
        self.googleAuth = googleAuth
        self.repository = repository
        self.agenda = AgendaModel(repository: repository)
        self.taskCreator = TaskCreationService(eventKit: eventKit, googleAuth: googleAuth, googleClient: googleClient)
        self.focus = FocusCoordinator()
        self.snapshot = SharedStore.shared.load()

        startObserving()
        FocusNotifier.requestAuthorization()
        focus.reconcile()
        applyDesktopPanelSetting()
        Log.app.info("Deskfocus started")
        Task { await refresh() }
    }

    // MARK: Actions

    /// Syncs today for the widget, then reloads the day or week the user is browsing.
    func refresh() async {
        await repository.refresh()
        reloadSnapshot()
        await agenda.reload()
    }

    /// Starts or resumes focus on a task from any day; `minutes` is the length picked for a to-do.
    /// Tasks outside today are remembered first so actions can find them.
    func startFocus(on task: DeskTask, minutes: Int? = nil) {
        SharedStore.shared.update { $0.reference(task) }
        FocusController.start(taskId: task.id, minutes: minutes)
        stateDidChange()
    }

    /// Checks off a task from any day.
    func complete(_ task: DeskTask) {
        SharedStore.shared.update { $0.reference(task) }
        FocusController.complete(taskId: task.id)
        stateDidChange()
    }

    /// Opens the "New task" window, preset to the day being viewed.
    func showAddTask() {
        addTaskWindow.show(model: self, day: agenda.selectedDay)
    }

    /// Creates the task in the chosen calendar or list, remembers its focus time and the list, then re-syncs.
    func createTask(_ draft: NewTaskDraft) async throws {
        let taskId = try await taskCreator.create(draft)
        updateSettings { $0.lastAddTargetId = draft.target.id }
        if !draft.target.createsEvent {
            SharedStore.shared.update { $0.taskFocusMinutes[taskId] = draft.focusMinutes }
        }
        await refresh()
    }

    /// Opens one day in the day layout, e.g. from a week column.
    func showDay(_ day: Date) {
        agenda.select(day: day)
        setPanelLayout(.day)
    }

    func setPanelLayout(_ layout: PanelLayout) {
        guard snapshot.settings.panelLayout != layout else { return }
        updateSettings { $0.panelLayout = layout }
        Log.app.info("Panel layout set to \(layout.rawValue, privacy: .public)")
    }

    func connectGoogle() async {
        googleErrorMessage = nil
        do {
            try await googleAuth.signIn()
            await refresh()
        } catch GoogleAuthService.AuthError.cancelled {
            Log.google.info("Google sign-in cancelled by the user")
        } catch {
            googleErrorMessage = error.localizedDescription
            Log.google.error("Google sign-in failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disconnectGoogle() async {
        await googleAuth.signOut()
        await refresh()
    }

    func requestCalendarAccess() async {
        await eventKit.requestCalendarAccess()
        await refresh()
    }

    func requestRemindersAccess() async {
        await eventKit.requestRemindersAccess()
        await refresh()
    }

    // MARK: Settings

    func updateSettings(_ mutate: (inout DeskfocusSettings) -> Void) {
        let saved = SharedStore.shared.update { mutate(&$0.settings) }
        snapshot = saved
        applyDesktopPanelSetting()
        WidgetCenter.shared.reloadTimelines(ofKind: DeskfocusConstants.widgetKind)
    }

    private func applyDesktopPanelSetting() {
        desktopPanel.update(isVisible: snapshot.settings.showDesktopPanel, layout: snapshot.settings.panelLayout, model: self)
    }

    /// Two-way binding to one setting, saved to the shared state on every change.
    func binding<Value>(_ keyPath: WritableKeyPath<DeskfocusSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.snapshot.settings[keyPath: keyPath] },
            set: { newValue in self.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    /// Binding for a source toggle; changing it re-syncs so the list matches right away.
    func sourceBinding(_ kind: TaskSourceKind) -> Binding<Bool> {
        Binding(
            get: { self.snapshot.settings.enabledSources.contains(kind) },
            set: { isOn in
                self.updateSettings { settings in
                    if isOn { settings.enabledSources.insert(kind) } else { settings.enabledSources.remove(kind) }
                }
                Task { await self.refresh() }
            }
        )
    }

    // MARK: Observation

    private func stateDidChange() {
        focus.reconcile()
        reloadSnapshot()
        Task { await repository.processPendingCompletions() }
    }

    private func reloadSnapshot() {
        snapshot = SharedStore.shared.load()
    }

    private func startObserving() {
        // Widget buttons change the state in another process; this keeps the app and guard in step.
        stateObserver = DarwinObserver(name: DeskfocusConstants.stateChangedNotification) { [weak self] in
            MainActor.assumeIsolated {
                self?.stateDidChange()
            }
        }

        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.refresh() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        notificationTokens.append(workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Log.app.info("Mac woke up, re-syncing")
                self.focus.reconcile()
                Task { await self.refresh() }
            }
        })
        notificationTokens.append(NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventKit.store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Log.sync.debug("Calendar database changed")
                Task { await self.refresh() }
            }
        })
        notificationTokens.append(NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Log.sync.info("New day, loading today's list")
                self.agenda.goToToday()
                Task { await self.refresh() }
            }
        })
    }
}
