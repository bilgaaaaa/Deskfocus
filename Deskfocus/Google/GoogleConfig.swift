import Foundation

/// OAuth settings for Google; the client id comes from Config/Secrets.xcconfig through Info.plist.
enum GoogleConfig {
    static let clientIdInfoKey = "GoogleClientID"
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

    /// Reversed client id, the custom URL scheme Google allows for this client type.
    static var redirectScheme: String {
        let prefix = clientId.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(prefix)"
    }

    static var redirectURI: String {
        "\(redirectScheme):/oauth2redirect"
    }
}
