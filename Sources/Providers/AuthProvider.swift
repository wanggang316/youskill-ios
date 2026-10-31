import CryptoKit
import Foundation
import Observation

/// Opens the sign-in page and returns the callback URL. The UI passes the system
/// web authentication session, so this layer needs no window.
typealias WebAuthenticate = @MainActor (_ url: URL, _ callbackScheme: String) async throws -> URL

enum AuthError: Error, Equatable {
    case notSignedIn
    case invalidCallback
    case providerFailed(String)
}

/// Owns the account session: sign-in with PKCE, token storage, and token refresh.
/// Other layers get an access token only through `withAccessToken`.
@MainActor
@Observable
final class AuthProvider {
    static let callbackScheme = "youskill-ios"
    static let redirectURI = "\(callbackScheme)://auth/callback"
    /// Refresh a little before expiry, so a request does not fail on the way.
    private static let expiryMargin: TimeInterval = 60

    private let repository: AccountRepositoryProtocol
    private let sessionStore: AccountSessionStoring
    private let now: () -> Date
    private let randomToken: () -> String

    private var session: AccountSession?
    @ObservationIgnored private var refreshTask: Task<AccountSession, Error>?

    private(set) var identity: AccountIdentity?

    init(
        repository: AccountRepositoryProtocol,
        sessionStore: AccountSessionStoring,
        now: @escaping () -> Date = Date.init,
        randomToken: @escaping () -> String = AuthProvider.makeRandomToken
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.now = now
        self.randomToken = randomToken
        session = sessionStore.load()
        identity = session?.identity
    }

    var isSignedIn: Bool { session != nil }

    func signIn(with provider: SignInProvider, authenticate: WebAuthenticate) async throws {
        let verifier = randomToken()
        let state = randomToken()
        let url = repository.signInURL(provider: provider, redirectURI: Self.redirectURI,
                                       codeChallenge: Self.codeChallenge(for: verifier), state: state)
        let callback = try await authenticate(url, Self.callbackScheme)

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func item(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if let error = item("error") {
            throw AuthError.providerFailed(error)
        }
        guard item("state") == state, let code = item("code"), !code.isEmpty else {
            throw AuthError.invalidCallback
        }

        let newSession = try await repository.exchange(code: code, codeVerifier: verifier,
                                                       redirectURI: Self.redirectURI)
        try store(newSession)
    }

    /// Revokes the session on the server when possible, then forgets it on this device.
    func signOut() async {
        if session != nil {
            try? await withAccessToken { [repository] token in try await repository.signOut(accessToken: token) }
        }
        endSession()
    }

    /// Deletes the account on the server. The session ends only after the server confirms.
    func deleteAccount() async throws {
        try await withAccessToken { [repository] token in try await repository.deleteAccount(accessToken: token) }
        endSession()
    }

    /// Runs an account request with a valid access token. A rejected token is refreshed
    /// once; a rejected refresh ends the session and throws `AccountAPIError.unauthorized`.
    func withAccessToken<T>(_ operation: (String) async throws -> T) async throws -> T {
        let token = try await validAccessToken()
        do {
            return try await operation(token)
        } catch AccountAPIError.unauthorized {
            return try await operation(try await refreshedAccessToken(replacing: token))
        }
    }

    private func validAccessToken() async throws -> String {
        guard let session else { throw AuthError.notSignedIn }
        if session.accessTokenExpiresAt.timeIntervalSince(now()) > Self.expiryMargin {
            return session.accessToken
        }
        return try await refreshedAccessToken(replacing: session.accessToken)
    }

    private func refreshedAccessToken(replacing staleToken: String) async throws -> String {
        guard let session else { throw AuthError.notSignedIn }
        if session.accessToken != staleToken {
            return session.accessToken
        }
        // Refresh tokens rotate and a reused one revokes the session, so concurrent
        // callers share one refresh.
        let task = refreshTask ?? Task { [repository] in
            try await repository.refresh(refreshToken: session.refreshToken)
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let refreshed = try await task.value
            if self.session?.refreshToken == session.refreshToken {
                try store(refreshed)
            }
            guard let current = self.session else { throw AuthError.notSignedIn }
            return current.accessToken
        } catch AccountAPIError.unauthorized {
            if self.session?.refreshToken == session.refreshToken {
                endSession()
            }
            throw AccountAPIError.unauthorized
        }
    }

    private func store(_ newSession: AccountSession) throws {
        try sessionStore.save(newSession)
        session = newSession
        identity = newSession.identity
    }

    private func endSession() {
        refreshTask = nil
        sessionStore.delete()
        session = nil
        identity = nil
    }

    static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }

    nonisolated static func makeRandomToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return Data((0 ..< 32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }).base64URLEncoded
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
