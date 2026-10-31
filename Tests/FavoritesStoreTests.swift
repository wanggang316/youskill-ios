import Foundation
import Testing
@testable import YouSkill

@MainActor
@Suite(.serialized)
struct FavoritesStoreTests {
    @Test
    func togglePersistsFavorites() throws {
        let defaults = makeDefaults()
        let store = FavoritesStore(userDefaults: defaults)

        store.toggle(makeSkill(id: 9))
        #expect(store.contains(makeSkill(id: 9)))

        let reloaded = FavoritesStore(userDefaults: defaults)
        #expect(reloaded.contains(makeSkill(id: 9)))
        #expect(reloaded.favorites.first?.id == 9)
        #expect(reloaded.favorites.first?.snapshot.source == "demo/repo")
    }

    @Test
    func toggleWhileSignedOutKeepsPendingChangesAndTombstones() {
        var clock = Date(timeIntervalSince1970: 100)
        let store = FavoritesStore(userDefaults: makeDefaults(), now: { clock })
        var changes = 0
        store.onLocalChange = { changes += 1 }

        store.toggle(makeSkill(id: 1))
        clock = Date(timeIntervalSince1970: 200)
        store.toggle(makeSkill(id: 1))

        #expect(changes == 2)
        #expect(store.favorites.isEmpty)
        #expect(store.filteredFavorites(searchText: "").isEmpty)
        let tombstone = store.pendingChanges.first
        #expect(tombstone?.state == .removed)
        #expect(tombstone?.updatedAt == Date(timeIntervalSince1970: 200))
        #expect(tombstone?.snapshot.name == "skill-1")
    }

    @Test
    func changeIsAlwaysLaterThanTheRecordItReplaces() {
        let clock = Date(timeIntervalSince1970: 100)
        let store = FavoritesStore(userDefaults: makeDefaults(), now: { clock })
        store.apply(remote(1, .favorited, at: 500))

        store.toggle(makeSkill(id: 1))

        #expect(store.record(for: 1)!.updatedAt > Date(timeIntervalSince1970: 500))
    }

    @Test
    func migratesLegacyFavoritesOnceAndKeepsDecodableRecords() throws {
        let defaults = makeDefaults()
        let legacy = """
        [
          {"id": 1, "name": "alpha", "source": "a/repo", "url": "https://github.com/a/repo", "path": "skills/alpha",
           "branch": "main", "installCount": 3, "starCount": 4, "addedAt": "2026-04-01T12:00:00.000Z"},
          {"id": "broken", "name": "no id"},
          {"id": 2, "name": "beta", "addedAt": "not a date", "installCount": "x"},
          42,
          {"id": 3, "source": "c/repo"},
          {"id": 1, "name": "duplicate"}
        ]
        """
        defaults.set(Data(legacy.utf8), forKey: FavoritesStore.legacyStorageKey)

        let store = FavoritesStore(userDefaults: defaults)

        #expect(store.records.map(\.skillID).sorted() == [1, 2, 3])
        let alpha = try #require(store.record(for: 1))
        #expect(alpha.updatedAt == ISO8601Formatters.makeWithFractionalSeconds().date(from: "2026-04-01T12:00:00.000Z"))
        #expect(alpha.snapshot == FavoriteSnapshot(name: "alpha", source: "a/repo", url: "https://github.com/a/repo",
                                                    path: "skills/alpha", branch: "main", installCount: 3, starCount: 4))
        #expect(alpha.isPending)
        #expect(store.record(for: 2)?.snapshot.name == "beta")
        #expect(store.record(for: 2)?.updatedAt == Date(timeIntervalSince1970: 0))
        #expect(store.record(for: 3)?.snapshot.name == "c/repo")

        // A second launch does not migrate again, so a removal stays removed.
        store.remove(skillID: 1)
        let reloaded = FavoritesStore(userDefaults: defaults)
        #expect(!reloaded.contains(makeSkill(id: 1)))
        #expect(reloaded.favorites.count == 2)
    }

    @Test
    func unreadableLegacyPayloadGivesEmptyFavorites() {
        let defaults = makeDefaults()
        defaults.set(Data("{not json".utf8), forKey: FavoritesStore.legacyStorageKey)

        #expect(FavoritesStore(userDefaults: defaults).records.isEmpty)
        #expect(defaults.data(forKey: FavoritesStore.legacyStorageKey) != nil)
    }

    @Test
    func serverRecordReplacesLocalRecordUnlessALaterChangeIsPending() {
        var clock = Date(timeIntervalSince1970: 100)
        let store = FavoritesStore(userDefaults: makeDefaults(), now: { clock })
        store.toggle(makeSkill(id: 1))

        store.apply(remote(1, .removed, at: 50))
        #expect(store.contains(makeSkill(id: 1)))
        #expect(store.record(for: 1)?.isPending == true)

        store.apply(remote(1, .removed, at: 150))
        #expect(!store.contains(makeSkill(id: 1)))
        #expect(store.pendingChanges.isEmpty)

        clock = Date(timeIntervalSince1970: 300)
        store.apply([remote(2, .favorited, at: 200)], cursor: 7)
        #expect(store.favorites.map(\.skillID) == [2])
        #expect(store.syncCursor == 7)
    }

    @Test
    func serverSnapshotKeepsLocalReaderFields() {
        let store = FavoritesStore(userDefaults: makeDefaults(), now: { Date(timeIntervalSince1970: 100) })
        store.toggle(makeSkill(id: 1))

        store.apply(RemoteFavorite(skillID: 1, state: .favorited, updatedAt: Date(timeIntervalSince1970: 200),
                                   snapshot: FavoriteSnapshot(name: "renamed", source: "demo/repo")))

        #expect(store.record(for: 1)?.snapshot.name == "renamed")
        #expect(store.record(for: 1)?.snapshot.path == "skills/skill-1")
    }

    @Test
    func revertRestoresServerRecordOrDropsTheRejectedAdd() {
        var clock = Date(timeIntervalSince1970: 100)
        let store = FavoritesStore(userDefaults: makeDefaults(), now: { clock })
        store.apply(remote(1, .removed, at: 50))
        store.toggle(makeSkill(id: 1))
        store.toggle(makeSkill(id: 2))
        let rejected1 = store.record(for: 1)!
        let rejected2 = store.record(for: 2)!

        store.revert(rejected1, to: remote(1, .removed, at: 50))
        store.revert(rejected2, to: nil)

        #expect(store.record(for: 1)?.state == .removed)
        #expect(store.record(for: 1)?.isPending == false)
        #expect(store.record(for: 2) == nil)

        // A change made after the rejected push is kept.
        store.toggle(makeSkill(id: 3))
        let rejected3 = store.record(for: 3)!
        clock = Date(timeIntervalSince1970: 200)
        store.toggle(makeSkill(id: 3))
        store.toggle(makeSkill(id: 3))
        store.revert(rejected3, to: nil)
        #expect(store.contains(makeSkill(id: 3)))
    }

    @Test
    func accountMergePushesFavoritesAndDropsTombstones() {
        let store = FavoritesStore(userDefaults: makeDefaults())
        store.apply([remote(1, .favorited, at: 10), remote(2, .removed, at: 10)], cursor: 4)

        store.prepareForAccountMerge()

        #expect(store.pendingChanges.map(\.skillID) == [1])
        #expect(store.records.count == 1)
        #expect(store.syncCursor == nil)
    }

    @Test
    func accountMergeKeepsLocalFavoriteOverTombstoneOnceAndSurvivesRelaunch() {
        let defaults = makeDefaults()
        let store = FavoritesStore(userDefaults: defaults, now: { Date(timeIntervalSince1970: 100) })
        store.toggle(makeSkill(id: 1))
        store.toggle(makeSkill(id: 2))
        store.prepareForAccountMerge()

        let reloaded = FavoritesStore(userDefaults: defaults, now: { Date(timeIntervalSince1970: 100) })
        #expect(reloaded.accountMergeIDs == [1, 2])
        let change = reloaded.record(for: 1)!

        #expect(reloaded.keepFavoriteForAccountMerge(change, over: remote(1, .removed, at: 500)))
        #expect(reloaded.record(for: 1)?.updatedAt == Date(timeIntervalSince1970: 500.001))
        #expect(reloaded.record(for: 1)?.isPending == true)
        // The merge of skill 1 is over; the next answer follows last write wins.
        #expect(!reloaded.keepFavoriteForAccountMerge(reloaded.record(for: 1)!, over: remote(1, .removed, at: 900)))
        // A favorited answer ends the merge without keeping anything.
        #expect(!reloaded.keepFavoriteForAccountMerge(reloaded.record(for: 2)!, over: remote(2, .favorited, at: 100)))
        #expect(reloaded.accountMergeIDs.isEmpty)
    }

    @Test
    func accountMergeDoesNotOverrideALaterLocalChange() {
        var clock = Date(timeIntervalSince1970: 100)
        let store = FavoritesStore(userDefaults: makeDefaults(), now: { clock })
        store.toggle(makeSkill(id: 1))
        store.prepareForAccountMerge()
        let pushed = store.record(for: 1)!
        clock = Date(timeIntervalSince1970: 200)
        store.toggle(makeSkill(id: 1))

        #expect(!store.keepFavoriteForAccountMerge(pushed, over: remote(1, .removed, at: 150)))
        #expect(store.record(for: 1)?.state == .removed)
        #expect(store.accountMergeIDs.isEmpty)
    }

    @Test
    func clearAllRemovesFavoritesCursorAndLegacyData() {
        let defaults = makeDefaults()
        defaults.set(Data("[]".utf8), forKey: FavoritesStore.legacyStorageKey)
        let store = FavoritesStore(userDefaults: defaults)
        store.toggle(makeSkill(id: 1))
        store.apply([], cursor: 3)

        store.clearAll()

        #expect(store.records.isEmpty)
        #expect(store.syncCursor == nil)
        #expect(store.accountMergeIDs.isEmpty)
        #expect(defaults.data(forKey: FavoritesStore.legacyStorageKey) == nil)
        let reloaded = FavoritesStore(userDefaults: defaults)
        #expect(reloaded.records.isEmpty)
        #expect(reloaded.syncCursor == nil)
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    private func remote(_ id: Int, _ state: FavoriteState, at seconds: TimeInterval) -> RemoteFavorite {
        RemoteFavorite(skillID: id, state: state, updatedAt: Date(timeIntervalSince1970: seconds),
                       snapshot: FavoriteSnapshot(name: "skill-\(id)"))
    }
}

func makeSkill(id: Int) -> Skill {
    Skill(
        id: id,
        name: "skill-\(id)",
        description: nil,
        url: "https://github.com/demo/repo",
        path: "skills/skill-\(id)",
        starCount: 30,
        heatScore: 0,
        installCount: 40,
        source: "demo/repo",
        branch: "main",
        skillPathSHA: nil,
        tags: [],
        createdAt: .now,
        updatedAt: .now
    )
}
