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
    let focus: FocusCoordinator

    private(set) var snapshot: DeskfocusSnapshot
    var googleErrorMessage: String?

    private static let refreshInterval: TimeInterval = 5 * 60

    @ObservationIgnored private var stateObserver: DarwinObserver?
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []

    init() {
        let eventKit = EventKitAccess()
        let googleAuth = GoogleAuthService()
        let googleClient = GoogleAPIClient(auth: googleAuth)

        self.eventKit = eventKit
        self.googleAuth = googleAuth
        self.repository = TaskRepository(sources: [
            AppleCalendarSource(access: eventKit),
            AppleRemindersSource(access: eventKit),
            GoogleCalendarSource(auth: googleAuth, client: googleClient),
            GoogleTasksSource(auth: googleAuth, client: googleClient)
        ])
        self.focus = FocusCoordinator()
        self.snapshot = SharedStore.shared.load()

        startObserving()
        FocusNotifier.requestAuthorization()
        focus.reconcile()
        Log.app.info("Deskfocus started")
        Task { await refresh() }
    }

    // MARK: Actions

    func refresh() async {
        await repository.refresh()
        reloadSnapshot()
    }

    func startFocus(on task: DeskTask) {
        FocusController.start(taskId: task.id)
        stateDidChange()
    }

    func pauseFocus() {
        FocusController.pause()
        stateDidChange()
    }

    func resumeFocus() {
        FocusController.resume()
        stateDidChange()
    }

    func stopFocus() {
        FocusController.stop()
        stateDidChange()
    }

    func complete(taskId: String) {
        FocusController.complete(taskId: taskId)
        stateDidChange()
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
        WidgetCenter.shared.reloadTimelines(ofKind: DeskfocusConstants.widgetKind)
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
                Task { await self.refresh() }
            }
        })
    }
}
