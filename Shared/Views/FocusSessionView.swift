import AppIntents
import SwiftUI

/// The running, paused or finished session: amber ring with the countdown, task title and controls.
/// Controls are App Intents so they work the same in the widget and the app.
struct FocusSessionView: View {
    @Environment(\.deskfocusAccent) private var accent

    enum Size {
        /// Side-by-side layout for the medium widget.
        case compact
        /// Stacked layout with a large ring for the panel and the large widget.
        case regular
    }

    let session: FocusSession
    let now: Date
    let settings: DeskfocusSettings
    var size: Size = .regular

    private var phase: FocusPhase { session.phase(at: now) }

    var body: some View {
        switch size {
        case .compact:
            HStack(spacing: 16) {
                ring(diameter: 104, lineWidth: 9, timeFontSize: 22)
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
                        Text("Focus mode on")
                            .font(.system(size: 11))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.14), in: Capsule())
                    }
                }
                ring(diameter: 176, lineWidth: 13, timeFontSize: 42)
                VStack(spacing: 4) {
                    Text(session.taskTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if let blockedLine {
                        Text(blockedLine)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                }
                controls(isCompact: false)
            }
        }
    }

    // MARK: Pieces

    private var statusLabel: some View {
        Label(statusText, systemImage: "scope")
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(accent.color)
    }

    private var statusText: String {
        switch phase {
        case .running: return String(localized: "FOCUSING")
        case .paused: return String(localized: "PAUSED")
        case .finished: return String(localized: "TIME'S UP")
        }
    }

    private var blockedLine: String? {
        guard phase != .finished, !settings.blockedBundleIds.isEmpty else { return nil }
        let count = settings.blockedBundleIds.count
        switch settings.blockingMode {
        case .quit: return count == 1 ? String(localized: "1 app blocked") : String(localized: "\(count) apps blocked")
        case .hide: return count == 1 ? String(localized: "1 app hidden") : String(localized: "\(count) apps hidden")
        }
    }

    private func ring(diameter: CGFloat, lineWidth: CGFloat, timeFontSize: CGFloat) -> some View {
        FocusRingView(progress: progress, lineWidth: lineWidth) {
            VStack(spacing: 2) {
                timeText
                    .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                Text(phase == .finished ? String(localized: "Nice work") : String(localized: "of \(Int(session.plannedDuration / 60)) min"))
                    .font(.system(size: max(10, timeFontSize * 0.27)))
                    .foregroundStyle(.secondary)
            }
            .padding(lineWidth)
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private var timeText: some View {
        switch phase {
        case .running(let endDate):
            Text(timerInterval: now...max(endDate, now), countsDown: true)
        case .paused(let remaining):
            Text(DeskTaskFormatter.clock(remaining))
        case .finished:
            Text("Done?")
        }
    }

    private var progress: Double {
        guard session.plannedDuration > 0 else { return 0 }
        return 1 - session.remaining(at: now) / session.plannedDuration
    }

    /// Compact puts a red stop icon next to the buttons; regular adds a full-width red "End Session" row.
    private func controls(isCompact: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                switch phase {
                case .running:
                    Button(intent: PauseFocusIntent()) {
                        Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DeskfocusGlassButtonStyle())
                case .paused:
                    Button(intent: ResumeFocusIntent()) {
                        Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DeskfocusGlassButtonStyle())
                case .finished:
                    Button(intent: StartFocusIntent(taskId: session.taskId)) {
                        Label("Again", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DeskfocusGlassButtonStyle())
                }

                Button(intent: CompleteTaskIntent(taskId: session.taskId)) {
                    Label("Done", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(DeskfocusPrimaryButtonStyle())

                if isCompact {
                    Button(intent: EndFocusIntent()) {
                        Image(systemName: phase == .finished ? "xmark" : "stop.fill")
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
                } else {
                    Button(intent: EndFocusIntent()) {
                        Label("End Session", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DeskfocusDangerButtonStyle())
                }
            }
        }
    }
}
