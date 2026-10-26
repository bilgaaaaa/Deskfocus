import Foundation

/// Runs a user Shortcut by name through the `shortcuts` command line tool, used to switch a macOS Focus mode.
enum ShortcutRunner {
    private static let executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")

    static func run(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["run", trimmed]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { finished in
            if finished.terminationStatus == 0 {
                Log.distraction.info("Shortcut \"\(trimmed, privacy: .public)\" finished")
            } else {
                Log.distraction.error("Shortcut \"\(trimmed, privacy: .public)\" exited with \(finished.terminationStatus)")
            }
        }

        do {
            try process.run()
            Log.distraction.info("Running shortcut \"\(trimmed, privacy: .public)\"")
        } catch {
            Log.distraction.error("Could not run shortcut \"\(trimmed, privacy: .public)\": \(error.localizedDescription, privacy: .public)")
        }
    }
}
