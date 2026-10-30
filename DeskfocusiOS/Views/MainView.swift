import SwiftUI

/// The app's one screen. With little width (iPhone, the closed iPhone Duo) it shows the day or the week, opening and
/// closing like the Mac widget; with room to spare (the open iPhone Duo, iPad) it shows both as a two-page spread.
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isShowingSettings = false

    /// Regular width, as on the open iPhone Duo's inner display: the day and the week side by side.
    private var isSpread: Bool { horizontalSizeClass == .regular }

    var body: some View {
        let settings = model.snapshot.settings

        NavigationStack {
            // Ticks every second while a timer runs so the ring moves; every half minute otherwise.
            TimelineView(.periodic(from: .distantPast, by: model.snapshot.focus == nil ? 30 : 1)) { context in
                content(now: context.date)
            }
            .background { MainBackground(tint: settings.glassTint) }
            .toolbar { barItems }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: isAddingTask) {
            AddTaskView(initialDay: model.newTaskDay ?? model.agenda.selectedDay, defaultFocusMinutes: settings.focusMinutes) {
                model.newTaskDay = nil
            }
            .environment(model)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environment(model)
        }
        .environment(\.deskfocusAccent, settings.accentColor)
        // A live view, unlike WidgetKit, so looping animations may run here.
        .environment(\.deskfocusAmbientMotion, true)
        .tint(settings.accentColor.color)
        .animation(DeskfocusMotion.reveal, value: model.snapshot.focus == nil)
        .animation(.easeInOut(duration: 0.3), value: settings.glassTint)
        .sensoryFeedback(.success, trigger: model.snapshot.completedTaskIds.count) { old, new in new > old }
        .sensoryFeedback(.start, trigger: model.snapshot.focus?.id) { old, new in new != nil && new != old }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if isSpread {
            PageSpread(now: now)
        } else {
            // One page at a time, opening to the week and closing to the day like the Mac widget.
            ZStack(alignment: .top) {
                switch model.snapshot.settings.panelLayout {
                case .day:
                    DayPage(now: now)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .week:
                    WeekPage(now: now)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(DeskfocusMotion.reveal, value: model.snapshot.settings.panelLayout)
        }
    }

    /// System bar items, so iPhone Duo can move them to its side strip; every item has a title for the overflow menu.
    @ToolbarContentBuilder
    private var barItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !isShowingCurrent {
                Button {
                    withAnimation(DeskfocusMotion.navigate) { model.agenda.goToToday() }
                } label: {
                    Label("Today", systemImage: "arrow.uturn.backward")
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !isSpread {
                let layout = model.snapshot.settings.panelLayout
                let title: LocalizedStringKey = layout == .day ? "Open week" : "Close to day"
                Button {
                    model.setPanelLayout(layout == .day ? .week : .day)
                } label: {
                    Label(title, systemImage: layout == .day ? "calendar" : "calendar.day.timeline.left")
                }
            }
            Button { isShowingSettings = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Button { model.showAddTask() } label: {
                Label("New task", systemImage: "plus")
            }
        }
    }

    /// False while browsing another day, or another week on the week page, when "Today" leads back.
    private var isShowingCurrent: Bool {
        let agenda = model.agenda
        if !isSpread && model.snapshot.settings.panelLayout == .week {
            return agenda.isShowingThisWeek
        }
        return agenda.isShowingToday
    }

    /// Open while the model holds a day for the "New task" sheet.
    private var isAddingTask: Binding<Bool> {
        Binding(
            get: { model.newTaskDay != nil },
            set: { isPresented in
                if !isPresented { model.newTaskDay = nil }
            }
        )
    }
}

/// The glass color behind everything, edge to edge, like the Mac widget's tinted glass.
private struct MainBackground: View {
    let tint: GlassTint

    var body: some View {
        ZStack {
            Color.black
            tint.gradient
        }
        .ignoresSafeArea()
    }
}
