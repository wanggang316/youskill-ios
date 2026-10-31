import Foundation
import Testing
@testable import YouSkill

@MainActor
@Suite(.serialized)
struct FavoriteSyncServiceTests {
    private let repository = FakeAccountRepository()
    private var clock = Clock()

    @Test
    func firstSignInPushesLocalFavoritesAndPullsTheUnion() async throws {
        let (store, sync, auth) = makeSync(signedIn: false)
        clock.set(100)
        store.toggle(makeSkill(id: 1))
        store.toggle(makeSkill(id: 2))
        store.toggle(makeSkill(id: 4))
        store.toggle(makeSkill(id: 4))
        repository.seed(2, .favorited, at: 50)
        repository.seed(3, .favorited, at: 60)

        try await sync.signIn(with: .github, authenticate: callback)

        #expect(auth.isSignedIn)
        #expect(Set(repository.pushed.flatMap { $0 }.map(\.skillID)) == [1, 2])
        #expect(repository.pulledCursors.first == .some(nil))
        #expect(Set(store.favorites.map(\.skillID)) == [1, 2, 3])
        #expect(store.pendingChanges.isEmpty)
        #expect(store.syncCursor != nil)
    }

    @Test
    func firstSignInKeepsLocalFavoritesOverNewerAccountTombstones() async throws {
        let (store, sync, _) = makeSync(signedIn: false)
        clock.set(100)
        store.toggle(makeSkill(id: 1))
        store.toggle(makeSkill(id: 2))
        // Removed on another device after the local add, and with that device's clock
        // ahead of this one, so even the sign-in time is earlier.
        repository.seed(1, .removed, at: 200)
        repository.seed(2, .removed, at: 10_000)
        clock.set(300)

        try await sync.signIn(with: .github, authenticate: callback)

        #expect(Set(store.favorites.map(\.skillID)) == [1, 2])
        #expect(repository.record(1)?.state == .favorited)
        #expect(repository.record(2)?.state == .favorited)
        #expect(store.pendingChanges.isEmpty)

        // After the merge, last write wins again: a later removal elsewhere applies.
        repository.seed(1, .removed, at: 400)
        await sync.sync()
        #expect(store.favorites.map(\.skillID) == [2])
    }

    @Test
    func lastWriteWinsInBothDirections() async {
        let (store, sync, _) = makeSync()
        repository.seed(1, .favorited, at: 10)
        repository.seed(2, .favorited, at: 500)
        await sync.sync()

        clock.set(100)
        store.remove(skillID: 1)
        store.apply(RemoteFavorite(skillID: 2, state: .removed, updatedAt: Date(timeIntervalSince1970: 100),
                                   snapshot: FavoriteSnapshot(name: "skill-2")))
        // A stale local change for skill 2: the server keeps its later record.
        store.toggle(makeSkill(id: 2))
        let staleChange = store.record(for: 2)!
        #expect(staleChange.updatedAt < Date(timeIntervalSince1970: 500))
        await sync.sync()

        #expect(repository.record(1)?.state == .removed)
        #expect(store.record(for: 1)?.state == .removed)
        #expect(store.record(for: 2)?.state == .favorited)
        #expect(store.record(for: 2)?.updatedAt == Date(timeIntervalSince1970: 500))
        #expect(store.pendingChanges.isEmpty)
    }

    @Test
    func pullAppliesTombstonesFromTheStoredCursor() async {
        let (store, sync, _) = makeSync()
        repository.seed(1, .favorited, at: 10)
        repository.seed(2, .favorited, at: 10)
        await sync.sync()
        let cursor = store.syncCursor
        #expect(store.favorites.count == 2)

        repository.seed(2, .removed, at: 20)
        await sync.sync()

        #expect(repository.pulledCursors.last == cursor)
        #expect(store.favorites.map(\.skillID) == [1])
        #expect(store.record(for: 2)?.state == .removed)
    }

    @Test
    func pullFollowsPagesUntilTheEnd() async {
        let (store, sync, _) = makeSync()
        repository.pageSize = 2
        for id in 1 ... 5 { repository.seed(id, .favorited, at: TimeInterval(id)) }

        await sync.sync()

        #expect(store.favorites.count == 5)
        #expect(repository.pulledCursors.count == 3)
    }

    @Test
    func offlineChangesStayPendingAndSyncLater() async {
        let (store, sync, _) = makeSync()
        repository.isOffline = true
        store.toggle(makeSkill(id: 1))

        await sync.sync()
        #expect(store.pendingChanges.map(\.skillID) == [1])

        repository.isOffline = false
        await sync.sync()
        #expect(store.pendingChanges.isEmpty)
        #expect(repository.record(1)?.state == .favorited)
    }

    @Test
    func limitRejectionRevertsTheAddAndShowsANotice() async {
        let (store, sync, _) = makeSync()
        repository.favoriteLimit = 1
        repository.seed(1, .favorited, at: 10)
        await sync.sync()

        store.toggle(makeSkill(id: 2))
        await sync.sync()

        #expect(!store.contains(makeSkill(id: 2)))
        #expect(store.pendingChanges.isEmpty)
        #expect(sync.notice == .favoriteLimitReached)
        #expect(store.favorites.map(\.skillID) == [1])
    }

    @Test
    func rejectedRefreshSignsOutAndKeepsLocalRecords() async {
        let (store, sync, auth) = makeSync()
        store.toggle(makeSkill(id: 1))
        repository.accessTokenIsRejected = true
        repository.refreshIsRejected = true

        await sync.sync()

        #expect(!auth.isSignedIn)
        #expect(store.pendingChanges.map(\.skillID) == [1])
        #expect(store.contains(makeSkill(id: 1)))
    }

    @Test
    func signOutClearsFavoritesAndCursor() async {
        let (store, sync, auth) = makeSync()
        repository.seed(1, .favorited, at: 10)
        await sync.sync()
        repository.signOutFails = true

        await sync.signOut()

        #expect(!auth.isSignedIn)
        #expect(store.records.isEmpty)
        #expect(store.syncCursor == nil)
        #expect(repository.calls.contains("signOut:access-1"))
    }

    @Test
    func deleteAccountClearsLocalDataOnlyAfterTheServerConfirms() async throws {
        let (store, sync, auth) = makeSync()
        repository.seed(1, .favorited, at: 10)
        await sync.sync()
        repository.deleteFails = true

        await #expect(throws: HTTPClientError.self) { try await sync.deleteAccount() }
        #expect(store.favorites.count == 1)
        #expect(auth.isSignedIn)

        repository.deleteFails = false
        try await sync.deleteAccount()
        #expect(store.records.isEmpty)
        #expect(!auth.isSignedIn)
    }

    @Test
    func localChangesAreDebouncedIntoOnePush() async throws {
        let (store, sync, _) = makeSync(debounce: .milliseconds(50))
        store.toggle(makeSkill(id: 1))
        store.toggle(makeSkill(id: 2))
        store.toggle(makeSkill(id: 3))

        var attempts = 0
        while !store.pendingChanges.isEmpty && attempts < 100 {
            try await Task.sleep(for: .milliseconds(20))
            attempts += 1
        }

        withExtendedLifetime(sync) {}
        #expect(repository.pushed.count == 1)
        #expect(repository.pushed.first?.count == 3)
    }

    @Test
    func concurrentSyncRequestsShareOneRunAndAddOnePass() async {
        let (store, sync, _) = makeSync()
        store.toggle(makeSkill(id: 1))

        async let first: Void = sync.sync()
        async let second: Void = sync.sync()
        async let third: Void = sync.sync()
        _ = await (first, second, third)

        #expect(repository.pushed.count == 1)
        // Requests made before the first pass starts are covered by it.
        #expect((1 ... 2).contains(repository.pulledCursors.count))
        #expect(store.pendingChanges.isEmpty)
    }

    @Test
    func signedOutSyncDoesNothing() async {
        let (store, sync, _) = makeSync(signedIn: false)
        store.toggle(makeSkill(id: 1))

        await sync.sync()

        #expect(repository.calls.isEmpty)
        #expect(store.pendingChanges.count == 1)
    }

    private var callback: WebAuthenticate {
        { url, _ in
            let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first { $0.name == "state" }?.value ?? ""
            return URL(string: "youskill-ios://auth/callback?code=c&state=\(state)")!
        }
    }

    private func makeSync(
        signedIn: Bool = true,
        debounce: Duration = .seconds(60)
    ) -> (FavoritesStore, FavoriteSyncService, AuthProvider) {
        let clock = clock
        let store = FavoritesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!, now: { clock.now })
        let auth = AuthProvider(
            repository: repository,
            sessionStore: InMemorySessionStore(signedIn ? FakeAccountRepository.session("access-1", refresh: "r") : nil)
        )
        let sync = FavoriteSyncService(favorites: store, auth: auth, repository: repository, debounce: debounce)
        return (store, sync, auth)
    }
}

@MainActor
private final class Clock {
    var now = Date(timeIntervalSince1970: 1)

    func set(_ seconds: TimeInterval) {
        now = Date(timeIntervalSince1970: seconds)
    }
}
