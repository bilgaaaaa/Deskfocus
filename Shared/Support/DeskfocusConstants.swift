import Foundation

/// Identifiers shared by the app and the widget extension.
enum DeskfocusConstants {
    /// Info.plist key holding the App Group identifier (expanded from the build settings at compile time).
    static let appGroupInfoKey = "DeskfocusAppGroupIdentifier"
    static let stateFileName = "deskfocus-state.json"
    static let widgetKind = "DeskfocusWidget"
    /// Darwin notification posted whenever the shared state changes in any process.
    static let stateChangedNotification = "com.bilgaaaaa.deskfocus.stateChanged"
}
