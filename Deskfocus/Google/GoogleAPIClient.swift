import Foundation

/// Authorised JSON requests to Google APIs, with paging handled in one place.
@MainActor
final class GoogleAPIClient {
    enum APIError: LocalizedError {
        case http(status: Int, body: String)
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .http(let status, let body): return String(localized: "Google API error \(status): \(String(body.prefix(200)))")
            case .invalidURL: return String(localized: "Could not build the Google API URL.")
            }
        }
    }

    private let auth: GoogleAuthService
    private let decoder = JSONDecoder()
    /// Safety cap so a broken pagination token can never loop forever.
    private let maxPages = 20

    init(auth: GoogleAuthService) {
        self.auth = auth
    }

    /// Fetches every page of a list endpoint and returns all items.
    func getAll<Item: Decodable>(_ baseURL: URL, query: [URLQueryItem] = [], as itemType: Item.Type) async throws -> [Item] {
        var items: [Item] = []
        var pageToken: String?
        var pageCount = 0

        repeat {
            var pageQuery = query
            if let pageToken { pageQuery.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let page: GooglePage<Item> = try await get(baseURL, query: pageQuery)
            items.append(contentsOf: page.items ?? [])
            pageToken = page.nextPageToken
            pageCount += 1
        } while pageToken != nil && pageCount < maxPages

        if pageToken != nil {
            Log.google.warning("Stopped paging \(baseURL.path, privacy: .public) after \(self.maxPages) pages")
        }
        return items
    }

    func get<Response: Decodable>(_ baseURL: URL, query: [URLQueryItem] = []) async throws -> Response {
        let url = try Self.url(baseURL, query: query)
        let data = try await send(url: url, method: "GET", body: nil)
        return try decoder.decode(Response.self, from: data)
    }

    /// Sends a JSON body and decodes the created resource.
    func post<Response: Decodable>(_ url: URL, json: [String: Any]) async throws -> Response {
        let data = try await send(url: url, method: "POST", body: try JSONSerialization.data(withJSONObject: json))
        return try decoder.decode(Response.self, from: data)
    }

    func patch(_ url: URL, json: [String: Any]) async throws {
        _ = try await send(url: url, method: "PATCH", body: try JSONSerialization.data(withJSONObject: json))
    }

    /// Encodes one path segment such as a calendar id ("abc@group.calendar.google.com", "…#holiday…").
    static func pathSegment(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~@")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func url(_ baseURL: URL, query: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    /// Sends an authorised request; when Google rejects the access token (401) it refreshes once and retries,
    /// and a refresh Google refuses ends the session in GoogleAuthService rather than looping here.
    private func send(url: URL, method: String, body: Data?) async throws -> Data {
        do {
            return try await sendOnce(url: url, method: method, body: body)
        } catch APIError.http(let status, _) where status == 401 {
            auth.invalidateAccessToken()
            return try await sendOnce(url: url, method: method, body: body)
        }
    }

    private func sendOnce(url: URL, method: String, body: Data?) async throws -> Data {
        let token = try await auth.validAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            Log.google.error("\(method, privacy: .public) \(url.path, privacy: .public) failed with \(status)")
            throw APIError.http(status: status, body: responseBody)
        }
        return data
    }
}
