import Foundation
import Observation

@MainActor
@Observable
final class FavoritesStore {
    private let storageKey = "favorite-skills"
    private let userDefaults: UserDefaults

    private(set) var favorites: [FavoriteSkill] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func contains(_ skill: Skill) -> Bool {
        favorites.contains { $0.id == skill.id }
    }

    func toggle(_ skill: Skill) {
        if contains(skill) {
            favorites.removeAll { $0.id == skill.id }
        } else {
            favorites.insert(FavoriteSkill(skill: skill), at: 0)
        }
        persist()
    }

    func filteredFavorites(searchText: String) -> [Skill] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = favorites
            .sorted { $0.addedAt > $1.addedAt }
            .map { $0.asSkill() }

        guard !search.isEmpty else {
            return items
        }

        return items.filter { skill in
            skill.name.localizedCaseInsensitiveContains(search)
                || (skill.source?.localizedCaseInsensitiveContains(search) ?? false)
        }
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? AppJSONCoders.decoder.decode([FavoriteSkill].self, from: data) else {
            favorites = []
            return
        }
        favorites = decoded.sorted { $0.addedAt > $1.addedAt }
    }

    private func persist() {
        guard let data = try? AppJSONCoders.encoder.encode(favorites) else { return }
        userDefaults.set(data, forKey: storageKey)
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

    func updateAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        userDefaults.set(language.rawValue, forKey: AppLanguage.storageKey)
    }

    private func persist() {
        guard let data = try? AppJSONCoders.encoder.encode(translationSettings) else { return }
        userDefaults.set(data, forKey: translationSettingsStorageKey)
    }
}
