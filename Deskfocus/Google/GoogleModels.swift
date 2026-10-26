import Foundation

/// Tokens kept in the Keychain after sign-in.
struct GoogleTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var email: String?

    /// Refresh a minute early so requests never race the expiry.
    func isValid(at now: Date = .now) -> Bool {
        expiresAt.timeIntervalSince(now) > 60
    }
}

struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

struct GoogleErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

struct GoogleUserInfo: Decodable {
    let email: String?
}

/// Any paged Google list response; every endpoint used here returns `items` plus `nextPageToken`.
struct GooglePage<Item: Decodable>: Decodable {
    let items: [Item]?
    let nextPageToken: String?
}

struct GoogleCalendarListEntry: Decodable {
    let id: String
    let summary: String?
    let summaryOverride: String?
    let backgroundColor: String?
    let selected: Bool?
    let hidden: Bool?
}

struct GoogleEvent: Decodable {
    let id: String
    let status: String?
    let summary: String?
    let start: GoogleEventTime?
    let end: GoogleEventTime?
}

/// Timed events use `dateTime`; all-day events use `date` (end date exclusive).
struct GoogleEventTime: Decodable {
    let dateTime: String?
    let date: String?
}

struct GoogleTaskList: Decodable {
    let id: String
    let title: String?
}

struct GoogleTaskItem: Decodable {
    let id: String
    let title: String?
    let status: String?
    let due: String?
}
