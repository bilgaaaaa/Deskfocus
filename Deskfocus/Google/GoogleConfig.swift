import Foundation

/// OAuth settings for Google; the client id and the sync switch come from the xcconfig files through Info.plist.
enum GoogleConfig {
    static let clientIdInfoKey = "GoogleClientID"
    static let syncEnabledInfoKey = "GoogleSyncEnabled"
    static let scopes = [
        "email",
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/tasks"
    ]

    static let authorizationURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    static let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke")!
    static let userInfoURL = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!

    static var clientId: String {
        (Bundle.main.object(forInfoDictionaryKey: clientIdInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// True once a real iOS-type client id ("….apps.googleusercontent.com") is configured.
    static var isConfigured: Bool {
        clientId.hasSuffix(".apps.googleusercontent.com")
    }

    /// False in public builds until Google verifies the app, because Google blocks everyone but the test users until then.
    static var isSyncEnabled: Bool {
        guard isConfigured else { return false }
        let value = (Bundle.main.object(forInfoDictionaryKey: syncEnabledInfoKey) as? String)?.uppercased()
        return value == "YES" || value == "1" || value == "TRUE"
    }

    /// Reversed client id, the custom URL scheme Google allows for this client type.
    static var redirectScheme: String {
        let prefix = clientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(prefix)"
    }

    static var redirectURI: String {
        "\(redirectScheme):/oauth2redirect"
    }
}
