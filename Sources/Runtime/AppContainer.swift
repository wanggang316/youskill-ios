import Foundation

final class AppContainer {
    let favoritesStore: FavoritesStore
    let settingsStore: AppSettingsStore
    let skillCatalogService: SkillCatalogService
    let skillContentService: SkillContentService
    let translationService: TranslationService

    init(
        favoritesStore: FavoritesStore,
        settingsStore: AppSettingsStore,
        skillCatalogService: SkillCatalogService,
        skillContentService: SkillContentService,
        translationService: TranslationService
    ) {
        self.favoritesStore = favoritesStore
        self.settingsStore = settingsStore
        self.skillCatalogService = skillCatalogService
        self.skillContentService = skillContentService
        self.translationService = translationService
    }

    @MainActor
    static func live() -> AppContainer {
        let favoritesStore = FavoritesStore()
        let settingsStore = AppSettingsStore()
        let httpClient = HTTPClient()

        return AppContainer(
            favoritesStore: favoritesStore,
            settingsStore: settingsStore,
            skillCatalogService: SkillCatalogService(
                repository: SkillCatalogRepository(httpClient: httpClient)
            ),
            skillContentService: SkillContentService(
                repository: GitHubContentRepository(httpClient: httpClient)
            ),
            translationService: TranslationService(
                repository: OpenAICompatibleTranslationRepository(httpClient: httpClient)
            )
        )
    }
}
