import Foundation
import Observation

/// Local favorites, the source of truth for the UI. Sync reads pending records and
/// writes server results back; the store itself knows nothing about accounts.
@MainActor
@Observable
final class FavoritesStore {
    static let legacyStorageKey = "favorite-skills"
    static let storageKey = "local-favorites"
    static let cursorStorageKey = "favorite-sync-cursor"

    private let userDefaults: UserDefaults
    private let now: () -> Date

    /// All records, tombstones included, newest first.
    private(set) var records: [LocalFavorite] = []
    private(set) var syncCursor: Int?

    /// Called after a person changes a favorite on this device.
    @ObservationIgnored var onLocalChange: (() -> Void)?

    init(userDefaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.userDefaults = userDefaults
        self.now = now
        load()
    }

    var favorites: [LocalFavorite] {
        records.filter(\.isFavorited)
    }

    var pendingChanges: [LocalFavorite] {
        records.filter(\.isPending)
    }

    func contains(_ skill: Skill) -> Bool {
        record(for: skill.id)?.isFavorited ?? false
    }

    func record(for skillID: Int) -> LocalFavorite? {
        records.first { $0.skillID == skillID }
    }

    func toggle(_ skill: Skill) {
        if contains(skill) {
            setState(.removed, skillID: skill.id, snapshot: nil)
        } else {
            setState(.favorited, skillID: skill.id, snapshot: FavoriteSnapshot(skill: skill))
        }
    }

    func remove(skillID: Int) {
        guard record(for: skillID)?.isFavorited == true else { return }
        setState(.removed, skillID: skillID, snapshot: nil)
    }

    func filteredFavorites(searchText: String) -> [Skill] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = favorites.map { $0.asSkill() }

        guard !search.isEmpty else {
            return items
        }

        return items.filter { skill in
            skill.name.localizedCaseInsensitiveContains(search)
                || (skill.source?.localizedCaseInsensitiveContains(search) ?? false)
        }
    }

    /// Replaces the local record with the server record, unless the local record has
    /// a later change that is not pushed yet.
    func apply(_ remote: RemoteFavorite) {
        applyWithoutSaving(remote)
        persist()
    }

    func apply(_ remotes: [RemoteFavorite], cursor: Int?) {
        remotes.forEach(applyWithoutSaving)
        if let cursor { syncCursor = cursor }
        persist()
    }

    /// Undoes a change that the server rejected. A later local change is kept.
    func revert(_ rejected: LocalFavorite, to remote: RemoteFavorite?) {
        guard let index = records.firstIndex(where: { $0.skillID == rejected.skillID }),
              records[index].updatedAt == rejected.updatedAt else { return }
        if let remote {
            records[index] = LocalFavorite(
                skillID: remote.skillID,
                state: remote.state,
                updatedAt: remote.updatedAt,
                snapshot: records[index].snapshot.merging(remote.snapshot),
                isPending: false
            )
        } else {
            records.remove(at: index)
        }
        sortRecords()
        persist()
    }

    /// Prepares the first sync of an account: every local favorite is pushed, local
    /// tombstones are dropped (the merge is a union), and the next pull starts from the beginning.
    func prepareForAccountMerge() {
        records = records.filter(\.isFavorited).map { record in
            var record = record
            record.isPending = true
            return record
        }
        syncCursor = nil
        persist()
    }

    /// Removes all favorites and sync state from this device.
    func clearAll() {
        records = []
        syncCursor = nil
        persist()
        userDefaults.removeObject(forKey: Self.legacyStorageKey)
    }

    private func setState(_ state: FavoriteState, skillID: Int, snapshot: FavoriteSnapshot?) {
        let existing = record(for: skillID)
        let record = LocalFavorite(
            skillID: skillID,
            state: state,
            // Last write wins on the server, so a change must be later than the record it replaces.
            updatedAt: max(now(), (existing?.updatedAt ?? .distantPast).addingTimeInterval(0.001)),
            snapshot: snapshot ?? existing?.snapshot ?? FavoriteSnapshot(name: String(skillID)),
            isPending: true
        )
        records.removeAll { $0.skillID == skillID }
        records.insert(record, at: 0)
        persist()
        onLocalChange?()
    }

    private func applyWithoutSaving(_ remote: RemoteFavorite) {
        let existing = records.firstIndex { $0.skillID == remote.skillID }
        if let existing, records[existing].isPending, records[existing].updatedAt > remote.updatedAt {
            return
        }
        let snapshot = existing.map { records[$0].snapshot.merging(remote.snapshot) } ?? remote.snapshot
        let record = LocalFavorite(
            skillID: remote.skillID,
            state: remote.state,
            updatedAt: remote.updatedAt,
            snapshot: snapshot,
            isPending: false
        )
        if let existing {
            records[existing] = record
        } else {
            records.append(record)
        }
        sortRecords()
    }

    private func sortRecords() {
        records.sort { $0.updatedAt > $1.updatedAt }
    }

    private func load() {
        if let data = userDefaults.data(forKey: Self.storageKey),
           let decoded = try? AppJSONCoders.decoder.decode([LossyElement<LocalFavorite>].self, from: data) {
            records = decoded.compactMap(\.value)
        } else if userDefaults.object(forKey: Self.storageKey) == nil {
            // The legacy key is read only, so the migration can run again safely after a crash.
            records = LegacyFavoritesMigration.records(from: userDefaults.data(forKey: Self.legacyStorageKey))
            persist()
        }
        sortRecords()
        syncCursor = userDefaults.object(forKey: Self.cursorStorageKey) as? Int
    }

    private func persist() {
        if let data = try? AppJSONCoders.encoder.encode(records) {
            userDefaults.set(data, forKey: Self.storageKey)
        }
        if let syncCursor {
            userDefaults.set(syncCursor, forKey: Self.cursorStorageKey)
        } else {
            userDefaults.removeObject(forKey: Self.cursorStorageKey)
        }
    }
}

private struct LossyElement<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// Reads favorites saved by versions before account sync. Each record decodes on its own,
/// and missing fields fall back to defaults, so one bad record never drops the others.
enum LegacyFavoritesMigration {
    static func records(from data: Data?) -> [LocalFavorite] {
        guard let data,
              let items = try? AppJSONCoders.decoder.decode([LossyRecord].self, from: data) else {
            return []
        }
        var seen = Set<Int>()
        return items.compactMap(\.record).filter { seen.insert($0.skillID).inserted }
    }

    private struct LossyRecord: Decodable {
        let record: LocalFavorite?

        init(from decoder: Decoder) throws {
            guard let container = try? decoder.container(keyedBy: CodingKeys.self),
                  let id = try? container.decode(Int.self, forKey: .id) else {
                record = nil
                return
            }
            func value<T: Decodable>(_ key: CodingKeys) -> T? {
                (try? container.decodeIfPresent(T.self, forKey: key)) ?? nil
            }
            let source: String? = value(.source)
            let name: String? = value(.name)
            record = LocalFavorite(
                skillID: id,
                state: .favorited,
                updatedAt: value(.addedAt) ?? Date(timeIntervalSince1970: 0),
                snapshot: FavoriteSnapshot(
                    name: name ?? source ?? String(id),
                    source: source,
                    url: value(.url),
                    path: value(.path),
                    branch: value(.branch),
                    installCount: value(.installCount),
                    starCount: value(.starCount)
                ),
                isPending: true
            )
        }

        private enum CodingKeys: String, CodingKey {
            case id, name, source, url, path, branch, installCount, starCount, addedAt
        }
    }
}

@MainActor
@Observable
final class AppSettingsStore {
    private let translationSettingsStorageKey = "translation-settings"
    private let userDefaults: UserDefaults

    var translationSettings: TranslationSettings
    var appLanguage: AppLanguage

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: translationSettingsStorageKey),
           let decoded = try? AppJSONCoders.decoder.decode(TranslationSettings.self, from: data) {
            translationSettings = decoded
        } else {
            translationSettings = .default
        }
        appLanguage = AppLanguage.current(userDefaults: userDefaults)
    }

    func update(_ settings: TranslationSettings) {
        translationSettings = settings
        persist()
    }

    func updateTargetLanguage(_ language: TargetLanguage) {
        translationSettings.targetLanguage = language
        persist()
    }

    func updateDisplayMode(_ mode: TranslationDisplayMode) {
        translationSettings.displayMode = mode
        persist()
    }

    func updateAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        userDefaults.set(language.rawValue, forKey: AppLanguage.storageKey)
    }

    private func persist() {
        guard let data = try? AppJSONCoders.encoder.encode(translationSettings) else { return }
        userDefaults.set(data, forKey: translationSettingsStorageKey)
    }
}
