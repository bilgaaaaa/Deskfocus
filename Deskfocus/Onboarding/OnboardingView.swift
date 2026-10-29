import AppKit
import SwiftUI

/// Pages of the welcome guide, in order.
private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case calendars
    case widget
    case ready

    var isFirst: Bool { self == Self.allCases.first }
    var isLast: Bool { self == Self.allCases.last }

    func moved(by offset: Int) -> OnboardingStep {
        Self(rawValue: rawValue + offset) ?? self
    }
}

/// First-launch guide: what Deskfocus does, connecting calendars, placing the widget and where Settings are.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    let onFinish: () -> Void
    @State private var step = OnboardingStep.welcome

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: WelcomePage()
                case .calendars: CalendarsPage()
                case .widget: WidgetPage()
                case .ready: ReadyPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .id(step)
            .transition(.opacity)

            Divider()
            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 560, height: 560)
        .environment(\.deskfocusAccent, model.snapshot.settings.accentColor)
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            PageDots(count: OnboardingStep.allCases.count, current: step.rawValue)
            Spacer()
            if !step.isFirst {
                Button("Back") { step = step.moved(by: -1) }
            }
            if step.isLast {
                Button("Start Using Deskfocus") {
                    Log.app.info("Welcome guide finished")
                    onFinish()
                }
                .buttonStyle(DeskfocusPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue") { step = step.moved(by: 1) }
                    .buttonStyle(DeskfocusPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

/// What Deskfocus is, in three lines.
private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)
            OnboardingHeader(
                title: "Welcome to Deskfocus",
                subtitle: "Today's tasks and a focus timer, right on your desktop."
            )
            VStack(alignment: .leading, spacing: 16) {
                OnboardingTipRow(systemImage: "calendar", title: "Your day in one list", text: "Events and to-dos from Calendar, Reminders and Google.")
                OnboardingTipRow(systemImage: "play.circle", title: "Focus on one thing", text: "Press ▶ on any task to start a timer and keep distracting apps away.")
                OnboardingTipRow(systemImage: "macwindow", title: "Always in sight", text: "A glass widget on your desktop, and Deskfocus in the menu bar.")
            }
            .padding(.horizontal, 40)
        }
        .padding(.top, 36)
    }
}

/// Access to calendars and reminders, the same controls as Settings › Calendars.
private struct CalendarsPage: View {
    var body: some View {
        VStack(spacing: 8) {
            OnboardingHeader(
                title: "Connect your calendars",
                subtitle: "Deskfocus shows the calendars and reminders on this Mac. Pick which ones any time in Settings › Calendars."
            )
            .padding(.horizontal, 32)
            .padding(.top, 28)
            Form {
                CalendarAccountsSection()
            }
            .formStyle(.grouped)
            .toggleStyle(ColorfulSwitchToggleStyle())
        }
    }
}

/// Showing the glass widget, and how to move it out of the way of other widgets.
private struct WidgetPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            OnboardingHeader(
                title: "Place your widget",
                subtitle: "The glass widget sits on your desktop, below your windows, on every desktop."
            )
            .padding(.horizontal, 32)
            .padding(.top, 28)
            Form {
                Section {
                    Toggle("Show glass widget on the desktop", isOn: model.binding(\.showDesktopPanel))
                    LabeledContent("Position") {
                        Button("Reset Widget Position") { model.resetDesktopPanelPosition() }
                    }
                }
                Section {
                    OnboardingTipRow(systemImage: "hand.draw", title: "Move it", text: "Drag the widget anywhere, for example away from your other widgets.")
                    OnboardingTipRow(systemImage: "contextualmenu.and.cursorarrow", title: "Change it", text: "Right-click it to open the week, pick colors or reset its position.")
                    OnboardingTipRow(systemImage: "square.grid.2x2", title: "Prefer a system widget?", text: "Right-click the desktop › Edit Widgets, search \"Deskfocus\" and pick medium or large.")
                }
            }
            .formStyle(.grouped)
            .toggleStyle(ColorfulSwitchToggleStyle())
        }
    }
}

/// Where Settings are, and keeping Deskfocus running.
private struct ReadyPage: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(spacing: 8) {
            OnboardingHeader(
                title: "You're all set",
                subtitle: "Change calendars, focus options and colors whenever you like."
            )
            .padding(.horizontal, 32)
            .padding(.top, 28)
            Form {
                Section {
                    OnboardingTipRow(systemImage: "gearshape", title: "Settings", text: "Click ⚙︎ on the widget, or the Deskfocus icon in the menu bar and then ⚙︎.")
                    OnboardingTipRow(systemImage: "plus.circle", title: "New task", text: "Click + on the widget to add an event or a to-do.")
                }
                Section {
                    Toggle("Open Deskfocus at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in
                            LaunchAtLogin.setEnabled(enabled)
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                } footer: {
                    Text("Keep this on so the timer and app hiding work even when you start focus from the widget.")
                }
            }
            .formStyle(.grouped)
            .toggleStyle(ColorfulSwitchToggleStyle())
        }
    }
}

/// Big title with a short explanation under it.
private struct OnboardingHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Icon in the accent color, a bold title and one line of explanation.
private struct OnboardingTipRow: View {
    @Environment(\.deskfocusAccent) private var accent
    let systemImage: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent.colors.deep)
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Small dots showing which page of the guide is open.
private struct PageDots: View {
    @Environment(\.deskfocusAccent) private var accent
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(Color.secondary.opacity(0.3)))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}
