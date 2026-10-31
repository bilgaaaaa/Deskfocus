import OSLog

/// Central loggers so every module logs under the same subsystem; filter with `subsystem:com.bilgaaaaa.deskfocus` in Console.app.
enum Log {
    private static let subsystem = "com.bilgaaaaa.deskfocus"

    static let store = Logger(subsystem: subsystem, category: "store")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let google = Logger(subsystem: subsystem, category: "google")
    static let focus = Logger(subsystem: subsystem, category: "focus")
    static let distraction = Logger(subsystem: subsystem, category: "distraction")
    static let widget = Logger(subsystem: subsystem, category: "widget")
    static let app = Logger(subsystem: subsystem, category: "app")
    static let update = Logger(subsystem: subsystem, category: "update")
}
