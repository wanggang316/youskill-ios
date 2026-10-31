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

    @Test(arguments: [AppLanguage.english, .simplifiedChinese, .japanese, .korean])
    func accountAndFavoriteSyncStringsExist(_ language: AppLanguage) {
        let keys = [
            "account.section", "account.signed_out_message", "account.sign_in_apple", "account.sign_in_github",
            "account.sign_in_failed", "account.signed_in_with", "account.identity_hint", "account.provider.apple",
            "account.provider.github", "account.sign_out", "account.sign_out_confirm_title",
            "account.sign_out_confirm_message", "account.delete", "account.delete_confirm_title",
            "account.delete_confirm_message", "account.delete_failed", "favorite.limit_reached_title",
            "favorite.limit_reached_message", "skill.unavailable"
        ]
        for key in keys {
            #expect(L10n.string(key, appLanguage: language) != key, "\(key) is missing")
        }
    }
}
