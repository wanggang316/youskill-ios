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
}
