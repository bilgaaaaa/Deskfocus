import Foundation

/// How the desktop panel shows tasks: one day at a time, or the whole week in a wider panel.
enum PanelLayout: String, Codable, CaseIterable {
    case day
    case week

    var displayName: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
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
        case .purple: return "Purple"
        case .indigo: return "Indigo"
        case .blue: return "Blue"
        case .teal: return "Teal"
        case .green: return "Green"
        case .orange: return "Orange"
        case .rose: return "Rose"
        case .graphite: return "Graphite"
        case .clear: return "Clear glass"
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
        case .amber: return "Amber"
        case .coral: return "Coral"
        case .pink: return "Pink"
        case .violet: return "Violet"
        case .sky: return "Sky"
        case .mint: return "Mint"
        case .lime: return "Lime"
        case .white: return "White"
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
        case .hide: return "Hide them"
        case .quit: return "Quit them (strict)"
        }
    }
}

/// User settings shared with the widget; decoding tolerates missing keys so older state files keep working.
struct DeskfocusSettings: Codable, Equatable {
    static let minimumFocusMinutes = 1
    static let maximumFocusMinutes = 240

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
    }

    /// Focus length clamped to a sane range, in seconds.
    var focusDuration: TimeInterval {
        TimeInterval(min(max(focusMinutes, Self.minimumFocusMinutes), Self.maximumFocusMinutes) * 60)
    }
}
