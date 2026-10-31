import Foundation
import Observation

enum FavoriteSyncNotice: Equatable {
    case favoriteLimitReached
}

/// Keeps local favorites and the account favorites in step: push pending changes,
/// then pull changes after the stored cursor. It also runs the account actions,
/// because each of them changes which favorites belong on this device.
@MainActor
@Observable
final class FavoriteSyncService {
    static let pushBatchSize = 200

    private let favorites: FavoritesStore
    private let auth: AuthProvider
    private let repository: AccountRepositoryProtocol
    private let debounce: Duration

    /// A message for the person, such as a rejected add.
    var notice: FavoriteSyncNotice?

    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var scheduledSync: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherPass = false
    /// Changes when the account on this device changes, so a sync that started for
    /// one account never writes into the favorites of the next.
    @ObservationIgnored private var generation = 0

    init(
        favorites: FavoritesStore,
        auth: AuthProvider,
        repository: AccountRepositoryProtocol,
        debounce: Duration = .seconds(1)
    ) {
        self.favorites = favorites
        self.auth = auth
        self.repository = repository
        self.debounce = debounce
        favorites.onLocalChange = { [weak self] in self?.scheduleSync() }
    }

    /// Signs in and merges the local favorites into the account as a union.
    func signIn(with provider: SignInProvider, authenticate: WebAuthenticate) async throws {
        try await auth.signIn(with: provider, authenticate: authenticate)
        generation += 1
        favorites.prepareForAccountMerge()
        await sync()
    }

    /// Clears the favorites on this device, so the next account never receives them.
    func signOut() async {
        generation += 1
        scheduledSync?.cancel()
        await auth.signOut()
        favorites.clearAll()
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
        generation += 1
        scheduledSync?.cancel()
        favorites.clearAll()
    }

    /// Syncs after a short delay, so a burst of local changes goes in one push.
    func scheduleSync() {
        scheduledSync?.cancel()
        scheduledSync = Task { [weak self, debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    /// Runs one sync. A request during a running sync adds one more pass after it.
    func sync() async {
        if let syncTask {
            needsAnotherPass = true
            await syncTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            repeat {
                needsAnotherPass = false
                await syncPass()
            } while needsAnotherPass
            // Same main-actor turn as the last check, so no request falls between them.
            syncTask = nil
        }
        syncTask = task
        await task.value
    }

    private func syncPass() async {
        guard auth.isSignedIn else { return }
        let generation = generation
        do {
            try await push(generation: generation)
            try await pull(generation: generation)
        } catch {
            // Pending changes stay pending and go out on the next sync. An unauthorized
            // error already moved the app to signed out; local records are kept.
        }
    }

    private func push(generation: Int) async throws {
        let pending = favorites.pendingChanges
        for start in stride(from: 0, to: pending.count, by: Self.pushBatchSize) {
            let batch = Array(pending[start ..< min(start + Self.pushBatchSize, pending.count)])
            let results = try await auth.withAccessToken { [repository] token in
                try await repository.pushFavorites(batch, accessToken: token)
            }
            guard generation == self.generation else { return }
            let resultsByID = Dictionary(results.map { ($0.skillID, $0) }, uniquingKeysWith: { $1 })
            for change in batch {
                guard let result = resultsByID[change.skillID] else { continue }
                switch result.status {
                case .applied, .ignored:
                    favorites.apply(result.record ?? RemoteFavorite(
                        skillID: change.skillID, state: change.state,
                        updatedAt: change.updatedAt, snapshot: change.snapshot
                    ))
                case .rejected:
                    favorites.revert(change, to: result.record)
                    if result.error == FavoriteChangeResult.limitReachedError {
                        notice = .favoriteLimitReached
                    }
                }
            }
        }
    }

    private func pull(generation: Int) async throws {
        while true {
            let cursor = favorites.syncCursor
            let page = try await auth.withAccessToken { [repository] token in
                try await repository.pullFavorites(cursor: cursor, accessToken: token)
            }
            guard generation == self.generation else { return }
            favorites.apply(page.records, cursor: page.cursor)
            guard page.hasMore, page.cursor != cursor else { return }
        }
    }
}
