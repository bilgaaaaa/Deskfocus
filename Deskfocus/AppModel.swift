#if os(macOS)
import AppKit
#endif
import EventKit
import Observation
import SwiftUI
import WidgetKit

/// Root of the app: owns the services, keeps them in sync with the shared state and exposes actions to the views.
/// The Mac and iPhone apps share it; the few platform parts are marked with `#if os`.
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
    /// Language the running app was launched with; a different choice needs a restart.
    let launchLanguage: AppLanguage
    /// Day the iPhone's "New task" sheet is open for, nil while it is closed; the Mac opens a window instead.
    var newTaskDay: Date?

    private static let refreshInterval: TimeInterval = 5 * 60

    #if os(macOS)
    private let desktopPanel = DesktopPanelController()
    private let addTaskWindow = AddTaskWindowController()
    private let settingsWindow = SettingsWindowController()
    private let onboardingWindow = OnboardingWindowController()
    #endif
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
        let snapshot = SharedStore.shared.load()
        self.snapshot = snapshot
        self.launchLanguage = snapshot.settings.language
        LanguagePreference.apply(snapshot.settings.language)

        startObserving()
        FocusNotifier.requestAuthorization()
        focus.reconcile()
        applyDesktopPanelSetting()
        Log.app.info("Deskfocus started")
        Task { await refresh() }
    }

    // MARK: Actions

    /// Saves the language for the app and widgets; it is used from the next launch.
    func setLanguage(_ language: AppLanguage) {
        updateSettings { $0.language = language }
        LanguagePreference.apply(language)
    }

    #if os(macOS)
    /// Opens a fresh copy of the app, then quits this one, so a new language takes effect.
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        Log.app.info("Restarting to apply settings")
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    Log.app.error("Restart failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                NSApp.terminate(nil)
            }
        }
    }
    #endif

    /// Brings the timer and the list up to date after time away: the Mac waking up or the iPhone app coming back.
    func catchUp() {
        focus.reconcile()
        reloadSnapshot()
        Task { await refresh() }
    }

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

    /// Ends focus on a task without completing it; its time left is forgotten.
    func endFocus(on task: DeskTask) {
        FocusController.end(taskId: task.id)
        stateDidChange()
    }

    /// Checks off a task from any day.
    func complete(_ task: DeskTask) {
        SharedStore.shared.update { $0.reference(task) }
        FocusController.complete(taskId: task.id)
        stateDidChange()
    }

    /// Opens the "New task" window on the Mac, or the sheet on iPhone, preset to the day being viewed.
    func showAddTask() {
        #if os(macOS)
        addTaskWindow.show(model: self, day: agenda.selectedDay)
        #else
        newTaskDay = agenda.selectedDay
        #endif
    }

    #if os(macOS)
    /// Opens the Settings window from the menu bar, the desktop widget or the welcome guide.
    func showSettings() {
        settingsWindow.show(model: self)
    }

    /// Opens the welcome guide, e.g. again from Settings › General.
    func showOnboarding() {
        onboardingWindow.show(model: self)
    }

    /// First launch: the welcome guide explains where calendars, the widget and Settings are.
    func showOnboardingIfNeeded() {
        guard !snapshot.settings.hasCompletedOnboarding else { return }
        Log.app.info("First launch, showing the welcome guide")
        showOnboarding()
    }

    /// Called when the welcome guide closes, finished or not, so it never comes back on its own.
    func completeOnboarding() {
        guard !snapshot.settings.hasCompletedOnboarding else { return }
        updateSettings { $0.hasCompletedOnboarding = true }
        Log.app.info("Welcome guide completed")
    }

    /// Opening Deskfocus again from Finder or Spotlight shows a window, since the app has no Dock icon.
    func handleReopen() {
        if snapshot.settings.hasCompletedOnboarding {
            showSettings()
        } else {
            showOnboarding()
        }
    }
    #endif

    /// Creates the task in the chosen calendar or list and remembers its focus time and the list.
    /// The re-sync runs in the background so the window can close right away.
    func createTask(_ draft: NewTaskDraft) async throws {
        let taskId = try await taskCreator.create(draft)
        updateSettings { $0.lastAddTargetId = draft.target.id }
        if !draft.target.createsEvent {
            SharedStore.shared.update { $0.rememberFocusMinutes(draft.focusMinutes, for: taskId, now: .now) }
        }
        Task { await refresh() }
    }

    /// Opens one day in the day layout, e.g. from a week column.
    func showDay(_ day: Date) {
        agenda.select(day: day)
        setPanelLayout(.day)
    }

    #if os(macOS)
    /// Moves the desktop widget while the user drags it; `translation` is how far the pointer moved since the drag began.
    func dragDesktopPanel(translation: CGSize) {
        desktopPanel.drag(mouseLocation: NSEvent.mouseLocation, translation: translation)
    }

    func endDesktopPanelDrag() {
        desktopPanel.endDrag()
    }

    /// Puts the desktop widget back in its first-launch spot, e.g. when it ended up behind other widgets.
    func resetDesktopPanelPosition() {
        if !snapshot.settings.showDesktopPanel {
            updateSettings { $0.showDesktopPanel = true }
        }
        desktopPanel.resetPosition()
    }
    #endif

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

    /// Shows, hides or morphs the Mac's desktop widget; the iPhone has none.
    private func applyDesktopPanelSetting() {
        #if os(macOS)
        desktopPanel.update(isVisible: snapshot.settings.showDesktopPanel, layout: snapshot.settings.panelLayout, model: self)
        #endif
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

    /// Binding for one calendar or list switch; changing it re-syncs so the list matches right away.
    func containerBinding(_ container: TaskContainer) -> Binding<Bool> {
        Binding(
            get: { !self.snapshot.settings.hiddenContainerKeys.contains(container.id) },
            set: { isOn in
                self.updateSettings { settings in
                    if isOn { settings.hiddenContainerKeys.remove(container.id) } else { settings.hiddenContainerKeys.insert(container.id) }
                }
                Log.sync.info("\(container.source.rawValue, privacy: .public) calendar switched \(isOn ? "on" : "off", privacy: .public)")
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

        #if os(macOS)
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        notificationTokens.append(workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Log.app.info("Mac woke up, re-syncing")
                self.catchUp()
            }
        })
        #else
        // Widget and Live Activity buttons run in this process, often woken in the background just for them;
        // the alert and the Live Activity are brought in line before the button's intent returns.
        FocusIntentObserver.stateDidChange = { [weak self] in
            guard let self else { return }
            self.stateDidChange()
            await self.focus.waitForLiveActivity()
        }
        #endif
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
