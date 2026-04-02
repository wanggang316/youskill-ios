import Testing
@testable import YouSkill

struct LocalizationTests {
    @Test
    func resolvesEnglishStrings() {
        #expect(L10n.string("settings.title", appLanguage: .english) == "Settings")
        #expect(L10n.string("detail.directory", appLanguage: .english) == "Catalog")
    }

    @Test
    func resolvesSimplifiedChineseStrings() {
        #expect(L10n.string("settings.title", appLanguage: .simplifiedChinese) == "设置")
        #expect(L10n.string("detail.directory", appLanguage: .simplifiedChinese) == "目录")
    }

    @Test
    func resolvesJapaneseStrings() {
        #expect(L10n.string("settings.title", appLanguage: .japanese) == "設定")
        #expect(L10n.string("detail.directory", appLanguage: .japanese) == "目次")
    }

    @Test
    func resolvesKoreanStrings() {
        #expect(L10n.string("settings.title", appLanguage: .korean) == "설정")
        #expect(L10n.string("detail.directory", appLanguage: .korean) == "목차")
    }
}
