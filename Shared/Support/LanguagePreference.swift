import Foundation

/// Applies the chosen language to the current process; macOS reads it when the app or widget next launches.
/// On iOS it does nothing: the language is picked in Settings › Apps › Deskfocus, and overriding it here would undo that choice.
enum LanguagePreference {
    private static let appleLanguagesKey = "AppleLanguages"

    static func apply(_ language: AppLanguage) {
        #if os(macOS)
        let defaults = UserDefaults.standard
        let current = defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?[appleLanguagesKey] as? [String]
        let wanted = language.code.map { [$0] }
        guard current != wanted else { return }

        if let wanted {
            defaults.set(wanted, forKey: appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: appleLanguagesKey)
        }
        Log.app.info("Language set to \(language.rawValue, privacy: .public), used from the next launch")
        #endif
    }
}
