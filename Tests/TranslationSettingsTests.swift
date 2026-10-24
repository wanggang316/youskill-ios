import Foundation
import Testing
@testable import YouSkill

@Suite
struct TranslationSettingsTests {
    @Test
    func defaultDisplayModeIsBilingual() {
        #expect(TranslationSettings.default.displayMode == .bilingual)
        #expect(TranslationDisplayMode.allCases == [.bilingual, .translation])
    }

    @Test
    func settingsSavedBeforeDisplayModesMigrateToBilingual() throws {
        let legacy = """
        {"baseURL":"https://example.com/v1","apiKey":"key","model":"m","targetLanguage":"japanese"}
        """

        let settings = try JSONDecoder().decode(TranslationSettings.self, from: Data(legacy.utf8))

        #expect(settings.displayMode == .bilingual)
        #expect(settings.targetLanguage == .japanese)
        #expect(settings.apiKey == "key")
    }

    @Test
    func unknownDisplayModeNormalizesToBilingual() throws {
        let stored = """
        {"baseURL":"b","apiKey":"k","model":"m","targetLanguage":"chinese","displayMode":"original"}
        """

        let settings = try JSONDecoder().decode(TranslationSettings.self, from: Data(stored.utf8))

        #expect(settings.displayMode == .bilingual)
    }

    @Test
    func displayModeRoundTrips() throws {
        var settings = TranslationSettings.default
        settings.displayMode = .translation

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(TranslationSettings.self, from: data)

        #expect(decoded == settings)
    }

    @Test
    func missingFieldsListEachEmptyValue() {
        let settings = TranslationSettings(baseURL: " ", apiKey: "", model: "gpt", targetLanguage: .chinese)

        #expect(settings.missingFields == [.baseURL, .apiKey])
        #expect(!settings.isComplete)
        #expect(TranslationSettings(baseURL: "b", apiKey: "k", model: "m", targetLanguage: .chinese).isComplete)
    }
}
