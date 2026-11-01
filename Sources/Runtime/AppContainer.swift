import Foundation

final class AppContainer {
    let favoritesStore: FavoritesStore
    let authProvider: AuthProvider
    let favoriteSyncService: FavoriteSyncService
    let settingsStore: AppSettingsStore
    let skillCatalogService: SkillCatalogService
    let skillContentService: SkillContentService
    let translationService: TranslationService

    private let networkMonitor = NetworkMonitor()

    init(
        favoritesStore: FavoritesStore,
        authProvider: AuthProvider,
        favoriteSyncService: FavoriteSyncService,
        settingsStore: AppSettingsStore,
        skillCatalogService: SkillCatalogService,
        skillContentService: SkillContentService,
        translationService: TranslationService
    ) {
        self.favoritesStore = favoritesStore
        self.authProvider = authProvider
        self.favoriteSyncService = favoriteSyncService
        self.settingsStore = settingsStore
        self.skillCatalogService = skillCatalogService
        self.skillContentService = skillContentService
        self.translationService = translationService
    }

    @MainActor
    static func live() -> AppContainer {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            // Each UI test starts with clean local state without changing release behavior.
            UserDefaults.standard.removePersistentDomain(forName: AppConfiguration.bundleIdentifier)
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-fixtures") {
            return uiTesting()
        }
#endif
        let favoritesStore = FavoritesStore()
        let settingsStore = AppSettingsStore()
        let httpClient = HTTPClient()
        let accountRepository = AccountRepository(httpClient: httpClient)
        let authProvider = AuthProvider(repository: accountRepository, sessionStore: KeychainAccountSessionStore())

        let container = AppContainer(
            favoritesStore: favoritesStore,
            authProvider: authProvider,
            favoriteSyncService: FavoriteSyncService(
                favorites: favoritesStore, auth: authProvider, repository: accountRepository
            ),
            settingsStore: settingsStore,
            skillCatalogService: SkillCatalogService(
                repository: SkillCatalogRepository(httpClient: httpClient)
            ),
            skillContentService: SkillContentService(
                repository: GitHubContentRepository(httpClient: httpClient)
            ),
            translationService: TranslationService(
                repository: ChatCompletionTranslationRepository(httpClient: httpClient)
            )
        )
        container.startNetworkMonitor()
        return container
    }

    @MainActor
    private func startNetworkMonitor() {
        networkMonitor.start { [weak self] in self?.favoriteSyncService.scheduleSync() }
    }
}
