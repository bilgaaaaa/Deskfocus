import Foundation

/// Reads and writes the shared snapshot with file coordination so the app and widget never overwrite each other.
final class SharedStore {
    static let shared = SharedStore()

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        fileURL = Self.resolveDirectory().appendingPathComponent(DeskfocusConstants.stateFileName)
        Log.store.info("Shared state file: \(self.fileURL.path, privacy: .public)")
    }

    func load() -> DeskfocusSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = DeskfocusSnapshot()
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
            snapshot = readSnapshot(at: url)
        }
        if let coordinationError {
            Log.store.error("Coordinated read failed: \(coordinationError.localizedDescription, privacy: .public)")
        }
        return snapshot
    }

    /// Applies a mutation as one coordinated read-modify-write and returns the saved snapshot.
    @discardableResult
    func update(_ mutate: (inout DeskfocusSnapshot) -> Void) -> DeskfocusSnapshot {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = DeskfocusSnapshot()
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { url in
            snapshot = readSnapshot(at: url)
            mutate(&snapshot)
            writeSnapshot(snapshot, to: url)
        }
        if let coordinationError {
            Log.store.error("Coordinated write failed: \(coordinationError.localizedDescription, privacy: .public)")
        }
        return snapshot
    }

    private func readSnapshot(at url: URL) -> DeskfocusSnapshot {
        guard FileManager.default.fileExists(atPath: url.path) else { return DeskfocusSnapshot() }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(DeskfocusSnapshot.self, from: data)
        } catch {
            Log.store.error("Could not read shared state, starting fresh: \(error.localizedDescription, privacy: .public)")
            return DeskfocusSnapshot()
        }
    }

    private func writeSnapshot(_ snapshot: DeskfocusSnapshot, to url: URL) {
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            Log.store.error("Could not write shared state: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Uses the App Group container when signed with a team; falls back to Application Support for unsigned builds.
    private static func resolveDirectory() -> URL {
        let fileManager = FileManager.default
        if let groupId = Bundle.main.object(forInfoDictionaryKey: DeskfocusConstants.appGroupInfoKey) as? String,
           !groupId.isEmpty,
           let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupId) {
            return groupURL
        }

        Log.store.warning("App Group container unavailable; the widget will not see shared state")
        let fallback = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Deskfocus", isDirectory: true)
        do {
            try fileManager.createDirectory(at: fallback, withIntermediateDirectories: true)
        } catch {
            Log.store.error("Could not create fallback directory: \(error.localizedDescription, privacy: .public)")
        }
        return fallback
    }
}
