import AppIntents
import SwiftUI

/// The running, paused or finished session: accent ring with the countdown, task title and controls.
/// Controls are App Intents so they work the same in the widget and the app.
struct FocusSessionView: View {
    @Environment(\.deskfocusAccent) private var accent
    @Environment(\.deskfocusAmbientMotion) private var ambientMotion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Size {
        /// Side-by-side layout for the medium widget.
        case compact
        /// Stacked layout for the panel and the large widget; the ring shrinks when the space is short.
        case regular
    }

    let session: FocusSession
    let now: Date
    let settings: DeskfocusSettings
    var size: Size = .regular

    private var phase: FocusPhase { session.phase(at: now) }

    private var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    private var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    var body: some View {
        Group {
            switch size {
            case .compact:
                HStack(spacing: 16) {
                    ring(diameter: 104, lineWidth: 9, timeFontSize: 22, shrinksToFit: false)
                    VStack(alignment: .leading, spacing: 8) {
                        statusLabel
                        Text(session.taskTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        controls(isCompact: true)
                    }
                }
            case .regular:
                VStack(spacing: 14) {
                    HStack {
                        statusLabel
                        Spacer()
                        if !settings.focusOnShortcutName.isEmpty, phase != .finished {
                            focusModeChip
                                .transition(.opacity)
                        }
                    }
                    ring(diameter: 176, lineWidth: 13, timeFontSize: 42, shrinksToFit: true)
                    VStack(spacing: 4) {
                        Text(session.taskTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        if let blockedLine {
                            Label(blockedLine, systemImage: settings.blockingMode == .quit ? "nosign" : "eye.slash")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }
                    controls(isCompact: false)
                }
            }
        }
        .animation(DeskfocusMotion.reveal, value: phase)
    }

    // MARK: Pieces

    /// Status with an icon that swaps per phase, pulses while paused and bounces when the time is up.
    private var statusLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: statusSymbol)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, options: .repeating, isActive: isPaused && ambientMotion && !reduceMotion)
                .symbolEffect(.bounce, value: phase == .finished)
            Text(statusText)
        }
        .font(.system(size: 11, weight: .bold))
        .tracking(0.8)
        .foregroundStyle(accent.color)
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: String {
        switch phase {
        case .running: return "scope"
        case .paused: return "pause.circle.fill"
        case .finished: return "bell.fill"
        }
    }

    private var statusText: String {
        switch phase {
        case .running: return String(localized: "FOCUSING")
        case .paused: return String(localized: "PAUSED")
        case .finished: return String(localized: "TIME'S UP")
        }
    }

    private var focusModeChip: some View {
        Label("Focus mode on", systemImage: "moon.fill")
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(DeskfocusTheme.glassStroke))
    }

    private var blockedLine: String? {
        guard phase != .finished, !settings.blockedBundleIds.isEmpty else { return nil }
        let count = settings.blockedBundleIds.count
        switch settings.blockingMode {
        case .quit: return count == 1 ? String(localized: "1 app blocked") : String(localized: "\(count) apps blocked")
        case .hide: return count == 1 ? String(localized: "1 app hidden") : String(localized: "\(count) apps hidden")
        }
    }

    /// `shrinksToFit` lets the ring give up height to the text and buttons, e.g. in the large widget.
    private func ring(diameter: CGFloat, lineWidth: CGFloat, timeFontSize: CGFloat, shrinksToFit: Bool) -> some View {
        FocusRingView(progress: progress, lineWidth: lineWidth, glows: phase != .finished, breathes: isRunning, showsKnob: true) {
            VStack(spacing: 2) {
                timeText
                    .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(isPaused ? 0.55 : 1)
                    .animation(DeskfocusMotion.digitRoll, value: Int(session.remaining(at: now).rounded()))
                Text(phase == .finished ? String(localized: "Nice work") : String(localized: "of \(Int(session.plannedDuration / 60)) min"))
                    .font(.system(size: max(10, timeFontSize * 0.27)))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .padding(lineWidth)
        }
        .overlay {
            if ambientMotion && !reduceMotion {
                FinishBurst(isFinished: phase == .finished, lineWidth: lineWidth)
            }
        }
        .animation(DeskfocusMotion.ringTick, value: progress)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: diameter, maxHeight: diameter)
        .frame(width: shrinksToFit ? nil : diameter, height: shrinksToFit ? nil : diameter)
        .layoutPriority(shrinksToFit ? -1 : 0)
    }

    /// Live surfaces redraw every second, so the digits roll; WidgetKit counts down by itself between entries.
    @ViewBuilder
    private var timeText: some View {
        switch phase {
        case .running(let endDate):
            if ambientMotion {
                Text(DeskTaskFormatter.clock(endDate.timeIntervalSince(now)))
                    .contentTransition(.numericText(countsDown: true))
                    .transition(Self.timeSwap)
            } else {
                Text(timerInterval: now...max(endDate, now), countsDown: true)
                    .transition(Self.timeSwap)
            }
        case .paused(let remaining):
            Text(DeskTaskFormatter.clock(remaining))
                .transition(Self.timeSwap)
        case .finished:
            Text("Done?")
                .transition(Self.timeSwap)
        }
    }

    private static let timeSwap = AnyTransition.scale(scale: 0.9).combined(with: .opacity)

    private var progress: Double {
        guard session.plannedDuration > 0 else { return 0 }
        return 1 - session.remaining(at: now) / session.plannedDuration
    }

    /// Regular: phase button, "+5 min" and Done, then a full-width red "End Session" (or "Dismiss") row.
    /// Compact: phase button (or "+5 min" once the time is up), Done and a red stop icon.
    private func controls(isCompact: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if isCompact && phase == .finished {
                    extendButton
                } else {
                    phaseButton
                }
                if !isCompact {
                    extendButton
                }

                Button(intent: CompleteTaskIntent(taskId: session.taskId)) {
                    Label("Done", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(DeskfocusPrimaryButtonStyle())

                if isCompact {
                    Button(intent: EndFocusIntent()) {
                        Image(systemName: phase == .finished ? "xmark" : "stop.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(DeskfocusDangerButtonStyle())
                    .help(phase == .finished ? "Dismiss" : "End Session")
                }
            }

            if !isCompact {
                if phase == .finished {
                    Button(intent: EndFocusIntent()) {
                        Label("Dismiss", systemImage: "xmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DeskfocusGlassButtonStyle())
                    .transition(.opacity)
                } else {
                    Button(intent: EndFocusIntent()) {
                        Label("End Session", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DeskfocusDangerButtonStyle())
                    .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private var phaseButton: some View {
        switch phase {
        case .running:
            Button(intent: PauseFocusIntent()) {
                Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(DeskfocusGlassButtonStyle())
            .transition(.opacity)
        case .paused:
            Button(intent: ResumeFocusIntent()) {
                Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(DeskfocusGlassButtonStyle())
            .transition(.opacity)
        case .finished:
            Button(intent: StartFocusIntent(taskId: session.taskId)) {
                Label("Again", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(DeskfocusGlassButtonStyle())
            .transition(.opacity)
        }
    }

    private var extendButton: some View {
        Button(intent: ExtendFocusIntent()) {
            Text("+\(FocusController.extensionMinutes) min")
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DeskfocusGlassButtonStyle())
        .help("Add \(FocusController.extensionMinutes) minutes")
    }
}

/// A ring of light that spreads out of the focus ring when the time is up; drawn on live surfaces only.
private struct FinishBurst: View {
    private enum Stage: CaseIterable {
        case rest
        case flash
        case spread
    }

    @Environment(\.deskfocusAccent) private var accent
    let isFinished: Bool
    let lineWidth: CGFloat

    var body: some View {
        PhaseAnimator(Stage.allCases, trigger: isFinished) { stage in
            Circle()
                .stroke(accent.gradient, lineWidth: lineWidth * 0.5)
                .scaleEffect(stage == .spread ? 1.3 : 1)
                .opacity(stage == .flash && isFinished ? 0.9 : 0)
        } animation: { stage in
            switch stage {
            case .rest: return .linear(duration: 0.01)
            case .flash: return .easeOut(duration: 0.12)
            case .spread: return .easeOut(duration: 0.8)
            }
        }
        .allowsHitTesting(false)
    }
}
