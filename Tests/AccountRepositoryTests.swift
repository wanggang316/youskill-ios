import Foundation
import Testing
@testable import YouSkill

@Suite(.serialized)
struct AccountRepositoryTests {
    private let base = "https://api.youskill.cc"

    @Test
    func signInURLCarriesRedirectChallengeAndState() throws {
        let url = makeRepository().signInURL(provider: .apple, redirectURI: "youskill-ios://auth/callback",
                                             codeChallenge: "challenge", state: "state-1")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/api/account/sign-in/apple")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        #expect(items["redirect_uri"] == "youskill-ios://auth/callback")
        #expect(items["code_challenge"] == "challenge")
        #expect(items["code_challenge_method"] == "S256")
        #expect(items["state"] == "state-1")
    }

    @Test
    func exchangeSendsVerifierAndParsesSession() async throws {
        MockURLProtocol.register(url: "\(base)/api/account/token") { request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "X-API-Key") == AppConfiguration.skillsAPIKey)
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body = try #require(try JSONSerialization.jsonObject(with: bodyData(of: request)) as? [String: String])
            #expect(body == ["code": "code-1", "code_verifier": "verifier", "redirect_uri": "youskill-ios://auth/callback"])
            return respond(request, 200, """
            {"access_token": "access", "refresh_token": "refresh", "token_type": "bearer", "expires_in": 900,
             "account": {"id": 5, "provider": "github", "display_name": "Ada", "email": null}}
            """)
        }

        let session = try await makeRepository().exchange(code: "code-1", codeVerifier: "verifier",
                                                          redirectURI: "youskill-ios://auth/callback")

        #expect(session == AccountSession(
            accessToken: "access", refreshToken: "refresh",
            accessTokenExpiresAt: Date(timeIntervalSince1970: 1_000 + 900),
            identity: AccountIdentity(provider: .github, displayName: "Ada", email: nil)
        ))
    }

    @Test
    func unauthorizedRefreshThrowsUnauthorized() async throws {
        MockURLProtocol.register(url: "\(base)/api/account/token/refresh") { request in
            respond(request, 401, #"{"detail": "Refresh token revoked"}"#)
        }

        await #expect(throws: AccountAPIError.unauthorized) {
            _ = try await makeRepository().refresh(refreshToken: "old")
        }
    }

    @Test
    func pushSendsChangesAndParsesEachResult() async throws {
        MockURLProtocol.register(url: "\(base)/api/account/favorites") { request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            let body = try #require(try JSONSerialization.jsonObject(with: bodyData(of: request)) as? [String: Any])
            let changes = try #require(body["changes"] as? [[String: Any]])
            #expect(changes.count == 2)
            #expect(changes[0]["skill_id"] as? Int == 1)
            #expect(changes[0]["state"] as? String == "favorited")
            #expect(changes[0]["name"] as? String == "skill-1")
            #expect(changes[0]["updated_at"] as? String == "1970-01-01T00:01:40.000Z")
            #expect(changes[1]["state"] as? String == "removed")
            return respond(request, 200, """
            {"results": [
              {"skill_id": 1, "status": "applied", "error": null,
               "record": {"skill_id": 1, "state": "favorited", "updated_at": "1970-01-01T00:01:40Z",
                          "name": "skill-1", "source": "demo/repo", "description": null}},
              {"skill_id": 2, "status": "rejected", "error": "favorite_limit_reached", "record": null}
            ]}
            """)
        }
        let changes = [
            LocalFavorite(skillID: 1, state: .favorited, updatedAt: Date(timeIntervalSince1970: 100),
                          snapshot: FavoriteSnapshot(name: "skill-1", source: "demo/repo"), isPending: true),
            LocalFavorite(skillID: 2, state: .removed, updatedAt: Date(timeIntervalSince1970: 100),
                          snapshot: FavoriteSnapshot(name: "skill-2"), isPending: true)
        ]

        let results = try await makeRepository().pushFavorites(changes, accessToken: "access")

        #expect(results == [
            FavoriteChangeResult(skillID: 1, status: .applied, error: nil, record: RemoteFavorite(
                skillID: 1, state: .favorited, updatedAt: Date(timeIntervalSince1970: 100),
                snapshot: FavoriteSnapshot(name: "skill-1", source: "demo/repo"))),
            FavoriteChangeResult(skillID: 2, status: .rejected, error: FavoriteChangeResult.limitReachedError, record: nil)
        ])
    }

    @Test
    func pullSendsCursorOnlyWhenPresentAndParsesTombstones() async throws {
        let page = """
        {"records": [{"skill_id": 3, "state": "removed", "updated_at": "2026-04-01T12:00:00Z",
                      "name": "gone", "source": "x/y", "description": "old"}],
         "cursor": 12, "has_more": false}
        """
        MockURLProtocol.register(url: "\(base)/api/account/favorites?limit=500") { request in
            respond(request, 200, page)
        }
        MockURLProtocol.register(url: "\(base)/api/account/favorites?limit=500&cursor=9") { request in
            respond(request, 200, page)
        }
        let repository = makeRepository()

        let first = try await repository.pullFavorites(cursor: nil, accessToken: "access")
        let next = try await repository.pullFavorites(cursor: 9, accessToken: "access")

        #expect(first == next)
        #expect(first.cursor == 12)
        #expect(!first.hasMore)
        #expect(first.records.first?.state == .removed)
        #expect(first.records.first?.snapshot == FavoriteSnapshot(name: "gone", source: "x/y", description: "old"))
    }

    @Test
    func signOutAndDeleteUseBearerToken() async throws {
        MockURLProtocol.register(url: "\(base)/api/account/sign-out") { request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            return respond(request, 204, "")
        }
        MockURLProtocol.register(url: "\(base)/api/account") { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access")
            return respond(request, 204, "")
        }
        let repository = makeRepository()

        try await repository.signOut(accessToken: "access")
        try await repository.deleteAccount(accessToken: "access")
    }

    private func makeRepository() -> AccountRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return AccountRepository(httpClient: HTTPClient(session: URLSession(configuration: configuration)),
                                 now: { Date(timeIntervalSince1970: 1_000) })
    }
}

private func respond(_ request: URLRequest, _ status: Int, _ body: String) -> (HTTPURLResponse, Data) {
    (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
}

private func bodyData(of request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        guard count > 0 else { break }
        data.append(buffer, count: count)
    }
    return data
}
