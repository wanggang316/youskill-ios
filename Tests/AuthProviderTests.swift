import Foundation
import Testing
@testable import YouSkill

@MainActor
@Suite(.serialized)
struct AuthProviderTests {
    @Test
    func signInSendsChallengeAndStoresTheSessionInTheStore() async throws {
        let repository = FakeAccountRepository()
        let store = InMemorySessionStore()
        let auth = AuthProvider(repository: repository, sessionStore: store, randomToken: { "fixed-token" })
        var openedURL: URL?

        try await auth.signIn(with: .apple) { url, scheme in
            openedURL = url
            #expect(scheme == "youskill-ios")
            return URL(string: "youskill-ios://auth/callback?code=code-1&state=fixed-token")!
        }

        let query = URLComponents(url: try #require(openedURL), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(openedURL?.path == "/sign-in/apple")
        #expect(query.first { $0.name == "code_challenge" }?.value == AuthProvider.codeChallenge(for: "fixed-token"))
        #expect(query.first { $0.name == "redirect_uri" }?.value == "youskill-ios://auth/callback")
        #expect(repository.calls == ["exchange:code-1:fixed-token"])
        #expect(auth.isSignedIn)
        #expect(auth.identity?.provider == .github)
        #expect(store.current?.accessToken == "access-1")
    }

    @Test
    func codeChallengeIsS256OfTheVerifier() {
        // RFC 7636 appendix B.
        #expect(AuthProvider.codeChallenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
            == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test
    func callbackWithWrongStateOrErrorDoesNotSignIn() async {
        let repository = FakeAccountRepository()
        let auth = AuthProvider(repository: repository, sessionStore: InMemorySessionStore(),
                                randomToken: { "expected" })

        await #expect(throws: AuthError.invalidCallback) {
            try await auth.signIn(with: .github) { _, _ in
                URL(string: "youskill-ios://auth/callback?code=c&state=other")!
            }
        }
        await #expect(throws: AuthError.providerFailed("access_denied")) {
            try await auth.signIn(with: .github) { _, _ in
                URL(string: "youskill-ios://auth/callback?error=access_denied&state=expected")!
            }
        }
        #expect(!auth.isSignedIn)
        #expect(repository.calls.isEmpty)
    }

    @Test
    func expiredAccessTokenRefreshesOnceForConcurrentCallers() async throws {
        let repository = FakeAccountRepository()
        let store = InMemorySessionStore(FakeAccountRepository.session(
            "old", refresh: "refresh-0", expiresAt: Date(timeIntervalSince1970: 0)))
        let auth = AuthProvider(repository: repository, sessionStore: store, now: { Date(timeIntervalSince1970: 100) })

        async let first = auth.withAccessToken { $0 }
        async let second = auth.withAccessToken { $0 }
        let tokens = try await [first, second]

        #expect(tokens == ["access-r1", "access-r1"])
        #expect(repository.refreshCount == 1)
        #expect(store.current?.refreshToken == "refresh-r1")
    }

    @Test
    func rejectedAccessTokenIsRefreshedAndRetried() async throws {
        let repository = FakeAccountRepository()
        repository.accessTokenIsRejected = true
        let auth = AuthProvider(repository: repository,
                                sessionStore: InMemorySessionStore(FakeAccountRepository.session("old", refresh: "r0")))

        try await auth.withAccessToken { token in try await repository.signOut(accessToken: token) }

        #expect(repository.calls == ["signOut:old", "refresh:r0", "signOut:access-r1"])
    }

    @Test
    func unauthorizedRefreshEndsTheSession() async {
        let repository = FakeAccountRepository()
        repository.accessTokenIsRejected = true
        repository.refreshIsRejected = true
        let store = InMemorySessionStore(FakeAccountRepository.session("old", refresh: "r0"))
        let auth = AuthProvider(repository: repository, sessionStore: store)

        await #expect(throws: AccountAPIError.unauthorized) {
            try await auth.withAccessToken { token in try await repository.pullFavorites(cursor: nil, accessToken: token) }
        }
        #expect(!auth.isSignedIn)
        #expect(auth.identity == nil)
        #expect(store.current == nil)
    }

    @Test
    func offlineRefreshKeepsTheSession() async {
        let repository = FakeAccountRepository()
        repository.isOffline = true
        let store = InMemorySessionStore(FakeAccountRepository.session(
            "old", refresh: "r0", expiresAt: Date(timeIntervalSince1970: 0)))
        let auth = AuthProvider(repository: repository, sessionStore: store)

        await #expect(throws: URLError.self) { try await auth.withAccessToken { $0 } }
        #expect(auth.isSignedIn)
    }

    @Test
    func signOutForgetsTheSessionWhenRevocationFails() async {
        let repository = FakeAccountRepository()
        repository.signOutFails = true
        let store = InMemorySessionStore(FakeAccountRepository.session("access", refresh: "r0"))
        let auth = AuthProvider(repository: repository, sessionStore: store)

        await auth.signOut()

        #expect(repository.calls == ["signOut:access"])
        #expect(!auth.isSignedIn)
        #expect(store.current == nil)
    }

    @Test
    func deleteAccountKeepsTheSessionUntilTheServerConfirms() async throws {
        let repository = FakeAccountRepository()
        repository.deleteFails = true
        let store = InMemorySessionStore(FakeAccountRepository.session("access", refresh: "r0"))
        let auth = AuthProvider(repository: repository, sessionStore: store)

        await #expect(throws: HTTPClientError.self) { try await auth.deleteAccount() }
        #expect(auth.isSignedIn)

        repository.deleteFails = false
        try await auth.deleteAccount()
        #expect(!auth.isSignedIn)
        #expect(store.current == nil)
    }
}
