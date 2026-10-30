import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The focus session on the Lock Screen and in the Dynamic Island: progress ring, countdown and the app's own buttons.
/// The ring and digits run by themselves between updates; past the end the activity turns stale and reads "Time's up".
struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusActivityLockScreenView(context: context)
                .activityBackgroundTint(context.attributes.tint.activityBackground)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FocusActivityRing(context: context)
                        .frame(width: 44, height: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusActivityTime(context: context)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    FocusActivityStatus(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    FocusActivityControls(context: context)
                        .padding(.top, 6)
                }
            } compactLeading: {
                FocusActivityRing(context: context)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                FocusActivityTime(context: context)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                FocusActivityRing(context: context)
                    .frame(width: 20, height: 20)
            }
            .keylineTint(context.attributes.accent.color)
        }
    }
}

/// Lock Screen and banner layout: ring, status and time in one line, the buttons below.
private struct FocusActivityLockScreenView: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                FocusActivityRing(context: context)
                    .frame(width: 46, height: 46)
                FocusActivityStatus(context: context)
                Spacer(minLength: 8)
                FocusActivityTime(context: context)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: 120, alignment: .trailing)
            }
            FocusActivityControls(context: context)
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

/// Accent ring that fills as the session runs, moving on its own between updates.
private struct FocusActivityRing: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        Group {
            switch context.state.phase {
            case .running(let endDate) where !context.isStale:
                ProgressView(timerInterval: context.state.progressStart(for: endDate)...endDate, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            case .paused(let remaining):
                ProgressView(value: min(max(1 - remaining / max(context.state.plannedDuration, 1), 0), 1))
            default:
                ProgressView(value: 1)
            }
        }
        .progressViewStyle(.circular)
        .tint(context.attributes.accent.color)
    }
}

/// Time left: counting down while running, frozen while paused, "Done?" once the time is up.
private struct FocusActivityTime: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        switch context.state.phase {
        case .running(let endDate) where !context.isStale:
            Text(timerInterval: context.state.progressStart(for: endDate)...endDate, countsDown: true)
                .multilineTextAlignment(.trailing)
        case .paused(let remaining):
            Text(DeskTaskFormatter.clock(remaining))
        default:
            Text("Done?")
        }
    }
}

/// "FOCUSING", "PAUSED" or "TIME'S UP" in the accent, above the task's title.
private struct FocusActivityStatus: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(statusText, systemImage: statusSymbol)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(context.attributes.accent.color)
            Text(context.attributes.taskTitle)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isFinished: Bool {
        context.isStale || context.state.phase == .finished
    }

    private var isPaused: Bool {
        if case .paused = context.state.phase { return true }
        return false
    }

    private var statusText: String {
        if isFinished { return String(localized: "TIME'S UP") }
        if isPaused { return String(localized: "PAUSED") }
        return String(localized: "FOCUSING")
    }

    private var statusSymbol: String {
        if isFinished { return "bell.fill" }
        if isPaused { return "pause.circle.fill" }
        return "scope"
    }
}

/// Pause or resume, "+5 min" once the time is up, and Done; the intents run in the app, which then updates this activity.
private struct FocusActivityControls: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        let accent = context.attributes.accent

        HStack(spacing: 8) {
            phaseButton
            Button(intent: CompleteTaskIntent(taskId: context.attributes.taskId)) {
                Label("Done", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(accent.gradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var phaseButton: some View {
        if context.isStale || context.state.phase == .finished {
            controlButton(intent: ExtendFocusIntent()) {
                Text("+\(FocusController.extensionMinutes) min")
            }
        } else if case .paused = context.state.phase {
            controlButton(intent: ResumeFocusIntent()) {
                Label("Resume", systemImage: "play.fill")
            }
        } else {
            controlButton(intent: PauseFocusIntent()) {
                Label("Pause", systemImage: "pause.fill")
            }
        }
    }

    private func controlButton<Content: View>(intent: some AppIntent, @ViewBuilder label: () -> Content) -> some View {
        Button(intent: intent) {
            label()
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Color.white.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private extension GlassTint {
    /// Lock Screen background: the tint's deep color, or the system's own material for clear glass.
    var activityBackground: Color? {
        self == .clear ? nil : colors.bottom.opacity(0.92)
    }
}
