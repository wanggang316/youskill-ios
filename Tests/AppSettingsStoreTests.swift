import Foundation
import Testing
@testable import YouSkill

@MainActor
@Suite(.serialized)
struct AppSettingsStoreTests {
    @Test
    func appLanguagePersistsAcrossReload() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = AppSettingsStore(userDefaults: defaults)

        store.updateAppLanguage(.japanese)
        store.updateTargetLanguage(.korean)

        let reloaded = AppSettingsStore(userDefaults: defaults)

        #expect(reloaded.appLanguage == .japanese)
        #expect(reloaded.translationSettings.targetLanguage == .korean)
    }

    @Test
    func displayModeDefaultsToBilingualAndPersists() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = AppSettingsStore(userDefaults: defaults)

        #expect(store.translationSettings.displayMode == .bilingual)

        store.updateDisplayMode(.translation)

        #expect(AppSettingsStore(userDefaults: defaults).translationSettings.displayMode == .translation)
    }

    @Test
    func storedSettingsWithoutDisplayModeMigrateToBilingual() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let legacy = #"{"baseURL":"https://example.com/v1","apiKey":"key","model":"gpt","targetLanguage":"korean"}"#
        defaults.set(Data(legacy.utf8), forKey: "translation-settings")

        let store = AppSettingsStore(userDefaults: defaults)

        #expect(store.translationSettings.displayMode == .bilingual)
        #expect(store.translationSettings.apiKey == "key")
        #expect(store.translationSettings.targetLanguage == .korean)
    }
}
