import Foundation

/// User settings shared with the widget; decoding tolerates missing keys so older state files keep working.
struct DeskfocusSettings: Codable, Equatable {
    static let minimumFocusMinutes = 1
    static let maximumFocusMinutes = 240

    var focusMinutes: Int = 25
    var blockedBundleIds: [String] = []
    var focusOnShortcutName: String = ""
    var focusOffShortcutName: String = ""
    var includeUndatedTasks: Bool = true
    var enabledSources: Set<TaskSourceKind> = Set(TaskSourceKind.allCases)

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = DeskfocusSettings()
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? defaults.focusMinutes
        blockedBundleIds = try container.decodeIfPresent([String].self, forKey: .blockedBundleIds) ?? defaults.blockedBundleIds
        focusOnShortcutName = try container.decodeIfPresent(String.self, forKey: .focusOnShortcutName) ?? defaults.focusOnShortcutName
        focusOffShortcutName = try container.decodeIfPresent(String.self, forKey: .focusOffShortcutName) ?? defaults.focusOffShortcutName
        includeUndatedTasks = try container.decodeIfPresent(Bool.self, forKey: .includeUndatedTasks) ?? defaults.includeUndatedTasks
        enabledSources = try container.decodeIfPresent(Set<TaskSourceKind>.self, forKey: .enabledSources) ?? defaults.enabledSources
    }

    /// Focus length clamped to a sane range, in seconds.
    var focusDuration: TimeInterval {
        TimeInterval(min(max(focusMinutes, Self.minimumFocusMinutes), Self.maximumFocusMinutes) * 60)
    }
}
