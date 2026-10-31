import Foundation
@testable import YouSkill

/// An in-memory account server that follows the sync rules of the real one:
/// last write wins on `updatedAt`, ties keep the stored record, tombstones stay,
/// and the cursor is a change sequence.
final class FakeAccountRepository: AccountRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Int: (record: RemoteFavorite, seq: Int)] = [:]
    private var seq = 0
    private var _calls: [String] = []
    private var _pushed: [[LocalFavorite]] = []
    private var _pulledCursors: [Int?] = []

    var favoriteLimit = 1000
    var pageSize = 500
    var isOffline = false
    var accessTokenIsRejected = false
    var refreshIsRejected = false
    var deleteFails = false
    var signOutFails = false
    var refreshCount = 0
    var nextSession = FakeAccountRepository.session("access-1", refresh: "refresh-1")

    var calls: [String] { lock.withLock { _calls } }
    var pushed: [[LocalFavorite]] { lock.withLock { _pushed } }
    var pulledCursors: [Int?] { lock.withLock { _pulledCursors } }

    static func session(_ access: String, refresh: String, expiresAt: Date = .distantFuture,
                        provider: SignInProvider = .github) -> AccountSession {
        AccountSession(accessToken: access, refreshToken: refresh, accessTokenExpiresAt: expiresAt,
                       identity: AccountIdentity(provider: provider, displayName: "Ada", email: "ada@example.com"))
    }

    /// Writes a record as another device would.
    func seed(_ id: Int, _ state: FavoriteState, at seconds: TimeInterval, name: String? = nil) {
        lock.withLock {
            seq += 1
            stored[id] = (RemoteFavorite(skillID: id, state: state, updatedAt: Date(timeIntervalSince1970: seconds),
                                         snapshot: FavoriteSnapshot(name: name ?? "skill-\(id)")), seq)
        }
    }

    func record(_ id: Int) -> RemoteFavorite? {
        lock.withLock { stored[id]?.record }
    }

    func signInURL(provider: SignInProvider, redirectURI: String, codeChallenge: String, state: String) -> URL {
        var components = URLComponents(string: "https://server.test/sign-in/\(provider.rawValue)")!
        components.queryItems = [URLQueryItem(name: "code_challenge", value: codeChallenge),
                                 URLQueryItem(name: "state", value: state),
                                 URLQueryItem(name: "redirect_uri", value: redirectURI)]
        return components.url!
    }

    func exchange(code: String, codeVerifier: String, redirectURI: String) async throws -> AccountSession {
        try lock.withLock {
            _calls.append("exchange:\(code):\(codeVerifier)")
            if isOffline { throw URLError(.notConnectedToInternet) }
            return nextSession
        }
    }

    func refresh(refreshToken: String) async throws -> AccountSession {
        try lock.withLock {
            _calls.append("refresh:\(refreshToken)")
            refreshCount += 1
            if isOffline { throw URLError(.notConnectedToInternet) }
            if refreshIsRejected { throw AccountAPIError.unauthorized }
            accessTokenIsRejected = false
            return Self.session("access-r\(refreshCount)", refresh: "refresh-r\(refreshCount)")
        }
    }

    func signOut(accessToken: String) async throws {
        try authorize("signOut", accessToken)
        if signOutFails { throw URLError(.notConnectedToInternet) }
    }

    func deleteAccount(accessToken: String) async throws {
        try authorize("delete", accessToken)
        try lock.withLock {
            if deleteFails { throw HTTPClientError.badStatusCode(500, "") }
            stored = [:]
        }
    }

    func pushFavorites(_ changes: [LocalFavorite], accessToken: String) async throws -> [FavoriteChangeResult] {
        try authorize("push", accessToken)
        return lock.withLock {
            _pushed.append(changes)
            var count = stored.values.filter { $0.record.state == .favorited }.count
            return changes.map { change in
                let existing = stored[change.skillID]
                if let existing, change.updatedAt <= existing.record.updatedAt {
                    return FavoriteChangeResult(skillID: change.skillID, status: .ignored, error: nil,
                                                record: existing.record)
                }
                let adds = change.state == .favorited && existing?.record.state != .favorited
                let removes = change.state == .removed && existing?.record.state == .favorited
                if adds && count >= favoriteLimit {
                    return FavoriteChangeResult(skillID: change.skillID, status: .rejected,
                                                error: FavoriteChangeResult.limitReachedError,
                                                record: existing?.record)
                }
                if adds { count += 1 }
                if removes { count -= 1 }
                seq += 1
                let record = RemoteFavorite(
                    skillID: change.skillID, state: change.state, updatedAt: change.updatedAt,
                    snapshot: FavoriteSnapshot(name: change.snapshot.name, source: change.snapshot.source,
                                               description: change.snapshot.description)
                )
                stored[change.skillID] = (record, seq)
                return FavoriteChangeResult(skillID: change.skillID, status: .applied, error: nil, record: record)
            }
        }
    }

    func pullFavorites(cursor: Int?, accessToken: String) async throws -> FavoriteChangesPage {
        try authorize("pull", accessToken)
        return lock.withLock {
            _pulledCursors.append(cursor)
            let changed = stored.values.filter { $0.seq > (cursor ?? 0) }.sorted { $0.seq < $1.seq }
            let page = Array(changed.prefix(pageSize))
            return FavoriteChangesPage(records: page.map(\.record), cursor: page.last?.seq ?? (cursor ?? 0),
                                       hasMore: changed.count > page.count)
        }
    }

    private func authorize(_ call: String, _ accessToken: String) throws {
        try lock.withLock {
            _calls.append("\(call):\(accessToken)")
            if isOffline { throw URLError(.notConnectedToInternet) }
            if accessTokenIsRejected { throw AccountAPIError.unauthorized }
        }
    }
}

final class InMemorySessionStore: AccountSessionStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var session: AccountSession?

    init(_ session: AccountSession? = nil) {
        self.session = session
    }

    var current: AccountSession? { lock.withLock { session } }

    func load() -> AccountSession? { current }
    func save(_ session: AccountSession) throws { lock.withLock { self.session = session } }
    func delete() { lock.withLock { session = nil } }
}
