import Foundation

/// How the desktop panel shows tasks: one day at a time, or the whole week in a wider panel.
enum PanelLayout: String, Codable, CaseIterable {
    case day
    case week

    var displayName: String {
        switch self {
        case .day: return String(localized: "Day")
        case .week: return String(localized: "Week")
        }
    }
}

/// Color of the glass widgets and the WidgetKit widget, picked from swatches in Settings or the panel's menu.
enum GlassTint: String, Codable, CaseIterable {
    case purple
    case indigo
    case blue
    case teal
    case green
    case orange
    case rose
    case graphite
    case clear

    var displayName: String {
        switch self {
        case .purple: return String(localized: "Purple")
        case .indigo: return String(localized: "Indigo")
        case .blue: return String(localized: "Blue")
        case .teal: return String(localized: "Teal")
        case .green: return String(localized: "Green")
        case .orange: return String(localized: "Orange")
        case .rose: return String(localized: "Rose")
        case .graphite: return String(localized: "Graphite")
        case .clear: return String(localized: "Clear glass")
        }
    }
}

/// Accent for buttons, the focus ring and highlights, chosen separately from the glass color.
enum AccentChoice: String, Codable, CaseIterable {
    case amber
    case coral
    case pink
    case violet
    case sky
    case mint
    case lime
    case white

    var displayName: String {
        switch self {
        case .amber: return String(localized: "Amber")
        case .coral: return String(localized: "Coral")
        case .pink: return String(localized: "Pink")
        case .violet: return String(localized: "Violet")
        case .sky: return String(localized: "Sky")
        case .mint: return String(localized: "Mint")
        case .lime: return String(localized: "Lime")
        case .white: return String(localized: "White")
        }
    }
}

/// What happens to blocked apps during focus.
enum BlockingMode: String, Codable, CaseIterable {
    /// Hide the apps and hide them again whenever they come to the front.
    case hide
    /// Quit the apps, quit them again if they are opened, and reopen them when the session ends.
    case quit

    var displayName: String {
        switch self {
        case .hide: return String(localized: "Hide them")
        case .quit: return String(localized: "Quit them (strict)")
        }
    }
}

/// User settings shared with the widget; decoding tolerates missing keys so older state files keep working.
struct DeskfocusSettings: Codable, Equatable {
    static let minimumFocusMinutes = 1
    static let maximumFocusMinutes = 480

    var focusMinutes: Int = 25
    var blockedBundleIds: [String] = []
    var blockingMode: BlockingMode = .hide
    var focusOnShortcutName: String = ""
    var focusOffShortcutName: String = ""
    var includeUndatedTasks: Bool = true
    var enabledSources: Set<TaskSourceKind> = Set(TaskSourceKind.allCases)
    var showDesktopPanel: Bool = true
    var panelLayout: PanelLayout = .day
    var glassTint: GlassTint = .purple
    var accentColor: AccentChoice = .amber
    /// Calendar or list picked last on the "New task" window.
    var lastAddTargetId: String?

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = DeskfocusSettings()
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? defaults.focusMinutes
        blockedBundleIds = try container.decodeIfPresent([String].self, forKey: .blockedBundleIds) ?? defaults.blockedBundleIds
        blockingMode = (try? container.decodeIfPresent(BlockingMode.self, forKey: .blockingMode)) ?? defaults.blockingMode
        focusOnShortcutName = try container.decodeIfPresent(String.self, forKey: .focusOnShortcutName) ?? defaults.focusOnShortcutName
        focusOffShortcutName = try container.decodeIfPresent(String.self, forKey: .focusOffShortcutName) ?? defaults.focusOffShortcutName
        includeUndatedTasks = try container.decodeIfPresent(Bool.self, forKey: .includeUndatedTasks) ?? defaults.includeUndatedTasks
        enabledSources = try container.decodeIfPresent(Set<TaskSourceKind>.self, forKey: .enabledSources) ?? defaults.enabledSources
        showDesktopPanel = try container.decodeIfPresent(Bool.self, forKey: .showDesktopPanel) ?? defaults.showDesktopPanel
        panelLayout = (try? container.decodeIfPresent(PanelLayout.self, forKey: .panelLayout)) ?? defaults.panelLayout
        glassTint = (try? container.decodeIfPresent(GlassTint.self, forKey: .glassTint)) ?? defaults.glassTint
        accentColor = (try? container.decodeIfPresent(AccentChoice.self, forKey: .accentColor)) ?? defaults.accentColor
        lastAddTargetId = try container.decodeIfPresent(String.self, forKey: .lastAddTargetId)
    }

    /// Fallback focus length for to-dos without a chosen time, in seconds.
    var focusDuration: TimeInterval {
        Self.clampedDuration(minutes: focusMinutes)
    }

    /// Any focus length clamped to the allowed range, in seconds.
    static func clampedDuration(minutes: Int) -> TimeInterval {
        TimeInterval(min(max(minutes, minimumFocusMinutes), maximumFocusMinutes) * 60)
    }

    /// Quick choices offered when starting a to-do.
    static let focusPresets = [15, 25, 45, 60, 90]
}
