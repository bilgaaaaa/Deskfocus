#if os(macOS)
import AppKit
#else
import UIKit
#endif
import AuthenticationServices
import CryptoKit
import Foundation
import Observation

/// Google sign-in with OAuth 2.0 + PKCE in the system browser sheet, with tokens kept in the Keychain.
@MainActor
@Observable
final class GoogleAuthService {
    enum AuthError: LocalizedError {
        case notConfigured
        case notConnected
        case cancelled
        case invalidCallback
        case stateMismatch
        case missingRefreshToken
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return String(localized: "Google client id is missing. Add it to Config/Secrets.xcconfig.")
            case .notConnected: return String(localized: "Google account is not connected.")
            case .cancelled: return String(localized: "Sign-in was cancelled.")
            case .invalidCallback: return String(localized: "Google returned an invalid sign-in response.")
            case .stateMismatch: return String(localized: "Sign-in response did not match the request.")
            case .missingRefreshToken: return String(localized: "Google did not return a refresh token. Remove Deskfocus from your Google account permissions and try again.")
            case .server(let message): return message
            }
        }
    }

    private static let keychainAccount = "google-tokens"

    private(set) var connectedEmail: String?
    private(set) var isConnected = false

    private var tokens: GoogleTokens?
    private var refreshTask: Task<String, Error>?
    private var authSession: ASWebAuthenticationSession?
    private let presentationProvider = AuthPresentationProvider()

    init() {
        if let data = KeychainStore.load(account: Self.keychainAccount),
           let saved = try? JSONDecoder().decode(GoogleTokens.self, from: data) {
            apply(saved)
            Log.google.info("Restored Google session")
        }
    }

    // MARK: Sign in / out

    func signIn() async throws {
        guard GoogleConfig.isConfigured else { throw AuthError.notConfigured }

        let verifier = Self.randomURLSafeString(byteCount: 32)
        let state = Self.randomURLSafeString(byteCount: 16)
        let code = try await requestAuthorizationCode(verifier: verifier, state: state)

        let response = try await postForm(to: GoogleConfig.tokenURL, fields: [
            "client_id": GoogleConfig.clientId,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": GoogleConfig.redirectURI
        ])
        guard let refreshToken = response.refreshToken else { throw AuthError.missingRefreshToken }

        var newTokens = GoogleTokens(
            accessToken: response.accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            email: nil
        )
        newTokens.email = await fetchEmail(accessToken: newTokens.accessToken)
        try persist(newTokens)
        Log.google.info("Google account connected")
    }

    func signOut() async {
        let tokenToRevoke = tokens?.refreshToken
        refreshTask?.cancel()
        refreshTask = nil
        tokens = nil
        connectedEmail = nil
        isConnected = false
        KeychainStore.delete(account: Self.keychainAccount)
        Log.google.info("Google account disconnected")

        // Revoking is best effort; local sign-out already happened.
        if let tokenToRevoke {
            var request = URLRequest(url: GoogleConfig.revokeURL)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formBody(["token": tokenToRevoke])
            do {
                _ = try await URLSession.shared.data(for: request)
            } catch {
                Log.google.error("Token revoke failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: Access token

    /// Returns a valid access token, refreshing once even when several requests ask at the same time.
    func validAccessToken() async throws -> String {
        guard let tokens else { throw AuthError.notConnected }
        if tokens.isValid() { return tokens.accessToken }
        if let refreshTask { return try await refreshTask.value }

        let task = Task { try await self.refreshAccessToken(using: tokens.refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func refreshAccessToken(using refreshToken: String) async throws -> String {
        do {
            let response = try await postForm(to: GoogleConfig.tokenURL, fields: [
                "client_id": GoogleConfig.clientId,
                "grant_type": "refresh_token",
                "refresh_token": refreshToken
            ])
            guard var updated = tokens else { throw AuthError.notConnected }
            updated.accessToken = response.accessToken
            updated.expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
            if let rotated = response.refreshToken { updated.refreshToken = rotated }
            try persist(updated)
            Log.google.debug("Access token refreshed")
            return updated.accessToken
        } catch AuthError.server(let message) where message.contains("invalid_grant") {
            // The user revoked access from their Google account; drop the dead session.
            Log.google.error("Refresh token rejected, signing out")
            await signOut()
            throw AuthError.notConnected
        }
    }

    // MARK: Helpers

    private func requestAuthorizationCode(verifier: String, state: String) async throws -> String {
        var components = URLComponents(url: GoogleConfig.authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: GoogleConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: Self.codeChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        guard let authURL = components.url else { throw AuthError.invalidCallback }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: GoogleConfig.redirectScheme) { url, error in
                if let error {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    continuation.resume(throwing: cancelled ? AuthError.cancelled : error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: AuthError.invalidCallback)
                }
            }
            session.presentationContextProvider = presentationProvider
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            #if os(macOS)
            // A menu bar app is not frontmost by default; the sign-in sheet needs it to be.
            NSApp.activate()
            #endif
            if !session.start() {
                continuation.resume(throwing: AuthError.invalidCallback)
            }
        }
        authSession = nil

        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw AuthError.server(error)
        }
        guard items.first(where: { $0.name == "state" })?.value == state else { throw AuthError.stateMismatch }
        guard let code = items.first(where: { $0.name == "code" })?.value else { throw AuthError.invalidCallback }
        return code
    }

    private func postForm(to url: URL, fields: [String: String]) async throws -> GoogleTokenResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody(fields)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let detail = (try? JSONDecoder().decode(GoogleErrorResponse.self, from: data))
                .map { "\($0.error): \($0.errorDescription ?? "")" } ?? "HTTP \(status)"
            Log.google.error("Token request failed: \(detail, privacy: .public)")
            throw AuthError.server(detail)
        }
        return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
    }

    private func fetchEmail(accessToken: String) async -> String? {
        var request = URLRequest(url: GoogleConfig.userInfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(GoogleUserInfo.self, from: data).email
        } catch {
            Log.google.error("Could not read account email: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func persist(_ newTokens: GoogleTokens) throws {
        let data = try JSONEncoder().encode(newTokens)
        try KeychainStore.save(data, account: Self.keychainAccount)
        apply(newTokens)
    }

    private func apply(_ newTokens: GoogleTokens) {
        tokens = newTokens
        connectedEmail = newTokens.email
        isConnected = true
    }

    private static func formBody(_ fields: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        // URLComponents leaves "+" unescaped, which form decoding would read as a space.
        return components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
            .data(using: .utf8)
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        if status != errSecSuccess {
            Log.google.error("SecRandomCopyBytes failed, using system random generator")
            bytes = (0..<byteCount).map { _ in UInt8.random(in: .min ... .max) }
        }
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }
}

/// Supplies the window the Google sign-in sheet attaches to.
private final class AuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // AuthenticationServices asks on the main thread; make that explicit for AppKit and UIKit access.
        MainActor.assumeIsolated {
            #if os(macOS)
            return NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) ?? ASPresentationAnchor()
            #else
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return scene?.keyWindow ?? scene.map { ASPresentationAnchor(windowScene: $0) } ?? ASPresentationAnchor()
            #endif
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
