import Foundation

enum AccountAPIError: Error, Equatable {
    /// The access or refresh token is expired, revoked, or unknown.
    case unauthorized
}

/// The account and favorite sync API of the YouSkill server. See docs/references/account-api.md.
protocol AccountRepositoryProtocol: Sendable {
    func signInURL(provider: SignInProvider, redirectURI: String, codeChallenge: String, state: String) -> URL
    func exchange(code: String, codeVerifier: String, redirectURI: String) async throws -> AccountSession
    func refresh(refreshToken: String) async throws -> AccountSession
    func signOut(accessToken: String) async throws
    func deleteAccount(accessToken: String) async throws
    func pushFavorites(_ changes: [LocalFavorite], accessToken: String) async throws -> [FavoriteChangeResult]
    func pullFavorites(cursor: Int?, accessToken: String) async throws -> FavoriteChangesPage
}

struct AccountRepository: AccountRepositoryProtocol {
    static let pullPageSize = 500

    private let httpClient: HTTPClient
    private let baseURL: URL
    private let now: @Sendable () -> Date

    init(
        httpClient: HTTPClient = HTTPClient(),
        baseURL: URL = AppConfiguration.apiBaseURL,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.now = now
    }

    func signInURL(provider: SignInProvider, redirectURI: String, codeChallenge: String, state: String) -> URL {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/account/sign-in/\(provider.rawValue)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        return components.url!
    }

    func exchange(code: String, codeVerifier: String, redirectURI: String) async throws -> AccountSession {
        let body = ["code": code, "code_verifier": codeVerifier, "redirect_uri": redirectURI]
        let response: TokenResponse = try await send("POST", "/api/account/token", body: body)
        return try response.session(receivedAt: now())
    }

    func refresh(refreshToken: String) async throws -> AccountSession {
        let response: TokenResponse = try await send("POST", "/api/account/refresh",
                                                     body: ["refresh_token": refreshToken])
        return try response.session(receivedAt: now())
    }

    func signOut(accessToken: String) async throws {
        _ = try await data("POST", "/api/account/sign-out", accessToken: accessToken)
    }

    func deleteAccount(accessToken: String) async throws {
        _ = try await data("DELETE", "/api/account", accessToken: accessToken)
    }

    func pushFavorites(_ changes: [LocalFavorite], accessToken: String) async throws -> [FavoriteChangeResult] {
        let body = PushRequest(changes: changes.map(FavoriteDTO.init))
        let response: PushResponse = try await send("POST", "/api/account/favorites", body: body,
                                                    accessToken: accessToken)
        return try response.results.map { try $0.result() }
    }

    func pullFavorites(cursor: Int?, accessToken: String) async throws -> FavoriteChangesPage {
        var query = [URLQueryItem(name: "limit", value: String(Self.pullPageSize))]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: String(cursor)))
        }
        let response: PullResponse = try await send("GET", "/api/account/favorites", query: query,
                                                    body: Optional<String>.none, accessToken: accessToken)
        return FavoriteChangesPage(records: try response.favorites.map { try $0.remote() },
                                   cursor: response.cursor, hasMore: response.hasMore)
    }

    private func send<Body: Encodable, Response: Decodable>(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Body?,
        accessToken: String? = nil
    ) async throws -> Response {
        let data = try await data(method, path, query: query, body: body, accessToken: accessToken)
        return try AppJSONCoders.decoder.decode(Response.self, from: data)
    }

    private func data(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (some Encodable)? = Optional<String>.none,
        accessToken: String? = nil
    ) async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // The app key names the client app; the bearer token names the account.
        request.setValue(AppConfiguration.skillsAPIKey, forHTTPHeaderField: "X-API-Key")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try AppJSONCoders.encoder.encode(body)
        }

        do {
            return try await httpClient.send(request)
        } catch HTTPClientError.badStatusCode(401, _) {
            throw AccountAPIError.unauthorized
        }
    }
}

private struct TokenResponse: Decodable {
    struct Identity: Decodable {
        let provider: SignInProvider
        let displayName: String?
        let email: String?

        enum CodingKeys: String, CodingKey {
            case provider
            case displayName = "display_name"
            case email
        }
    }

    struct Account: Decodable {
        let identities: [Identity]
    }

    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let account: Account

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case account
    }

    func session(receivedAt date: Date) throws -> AccountSession {
        // Identities are never linked in v1, so an account has exactly one.
        guard let identity = account.identities.first else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.account],
                                                    debugDescription: "Account has no sign-in identity"))
        }
        return AccountSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: date.addingTimeInterval(TimeInterval(expiresIn)),
            identity: AccountIdentity(provider: identity.provider, displayName: identity.displayName,
                                      email: identity.email)
        )
    }
}

private struct FavoriteDTO: Codable {
    struct Snapshot: Codable {
        let name: String
        let source: String?
        let description: String?
    }

    let skillID: Int
    let state: String
    let updatedAt: Date
    /// Required for `favorited`; the server returns null for most tombstones.
    let snapshot: Snapshot?

    enum CodingKeys: String, CodingKey {
        case skillID = "skill_id"
        case state
        case updatedAt = "updated_at"
        case snapshot
    }

    init(_ favorite: LocalFavorite) {
        skillID = favorite.skillID
        state = favorite.state.rawValue
        updatedAt = favorite.updatedAt
        snapshot = Snapshot(name: favorite.snapshot.name, source: favorite.snapshot.source,
                            description: favorite.snapshot.description)
    }

    func remote() throws -> RemoteFavorite {
        guard let state = FavoriteState(rawValue: state) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.state],
                                                    debugDescription: "Unknown favorite state: \(state)"))
        }
        return RemoteFavorite(
            skillID: skillID,
            state: state,
            updatedAt: updatedAt,
            snapshot: FavoriteSnapshot(name: snapshot?.name ?? String(skillID), source: snapshot?.source,
                                       description: snapshot?.description)
        )
    }
}

private struct PushRequest: Encodable {
    let changes: [FavoriteDTO]
}

private struct PushResponse: Decodable {
    struct Result: Decodable {
        let skillID: Int
        let status: String
        let error: String?
        let record: FavoriteDTO?

        enum CodingKeys: String, CodingKey {
            case skillID = "skill_id"
            case status
            case error
            case record
        }

        func result() throws -> FavoriteChangeResult {
            guard let parsed = FavoriteChangeStatus(rawValue: status) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.status],
                                                        debugDescription: "Unknown change status: \(status)"))
            }
            return FavoriteChangeResult(skillID: skillID, status: parsed, error: error, record: try record?.remote())
        }
    }

    let results: [Result]
}

private struct PullResponse: Decodable {
    let favorites: [FavoriteDTO]
    let cursor: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case favorites
        case cursor
        case hasMore = "has_more"
    }
}
