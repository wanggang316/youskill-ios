#if DEBUG
import Foundation

extension AppContainer {
    @MainActor
    static func uiTesting() -> AppContainer {
        let arguments = ProcessInfo.processInfo.arguments
        let translationCache = DiskCache(namespace: "ui-test-translations")
        if arguments.contains("--ui-testing") {
            // Cached translations are restored on open, so each test starts without them.
            translationCache.removeAll()
        }
        let settingsStore = AppSettingsStore()
        if arguments.contains("--ui-translation-configured") {
            settingsStore.update(TranslationSettings(
                baseURL: "https://example.invalid/v1",
                apiKey: "ui-test-key",
                model: "ui-test-model",
                targetLanguage: .chinese
            ))
        }

        let favoritesStore = FavoritesStore()
        if arguments.contains("--ui-unavailable-favorite") {
            // Skill 99 is not in the fixture catalog, like a skill that left the marketplace.
            favoritesStore.apply(RemoteFavorite(
                skillID: 99, state: .favorited, updatedAt: Date(timeIntervalSince1970: 0),
                snapshot: FavoriteSnapshot(name: "retired-skill", source: "example/archive")
            ))
        }
        let accountRepository = UITestAccount()
        let authProvider = AuthProvider(
            repository: accountRepository,
            sessionStore: UITestSessionStore(signedIn: arguments.contains("--ui-signed-in"))
        )

        return AppContainer(
            favoritesStore: favoritesStore,
            authProvider: authProvider,
            favoriteSyncService: FavoriteSyncService(
                favorites: favoritesStore, auth: authProvider, repository: accountRepository
            ),
            settingsStore: settingsStore,
            skillCatalogService: SkillCatalogService(repository: UITestCatalog()),
            skillContentService: SkillContentService(repository: UITestContent()),
            translationService: TranslationService(
                repository: UITestTranslation(),
                cache: translationCache
            )
        )
    }
}

private actor UITestCatalog: SkillCatalogRepositoryProtocol {
    private var shouldFail = ProcessInfo.processInfo.arguments.contains("--ui-error-once")

    func fetchSkills(query: SkillQuery) async throws -> SkillsPage {
        if shouldFail {
            shouldFail = false
            throw URLError(.notConnectedToInternet)
        }
        var skills = [makeSkill(id: 1, name: "find-skills", stars: 80, heat: 100),
                      makeSkill(id: 2, name: "review-code", stars: 120, heat: 50)]
        if !query.trimmedSearchText.isEmpty {
            skills = skills.filter { $0.name.localizedCaseInsensitiveContains(query.trimmedSearchText) }
        }
        if query.sortOption == .starCount { skills.sort { $0.starCount > $1.starCount } }
        let total = skills.count
        return SkillsPage(skills: Array(skills.dropFirst(query.skip).prefix(query.pageSize)),
                          total: total, page: query.page, pageSize: query.pageSize)
    }

    func fetchCategories() async throws -> [SkillCategory] {
        [SkillCategory(id: 1, name: "Development", icon: nil, skillCount: 2)]
    }

    func fetchHotRepositories() async throws -> [FeaturedRepository] {
        [FeaturedRepository(id: 1, name: "example/skills", icon: nil, skillCount: 2,
                            starCount: 120, enabled: true, type: "hot")]
    }

    func fetchSkill(id: Int) async throws -> Skill? {
        switch id {
        case 1: makeSkill(id: 1, name: "find-skills", stars: 80, heat: 100)
        case 2: makeSkill(id: 2, name: "review-code", stars: 120, heat: 50)
        default: nil
        }
    }

    private func makeSkill(id: Int, name: String, stars: Int, heat: Int) -> Skill {
        Skill(id: id, name: name, description: "A sample skill for UI acceptance tests.",
              url: "https://github.com/example/skills", path: "skills/\(name)",
              starCount: stars, heatScore: heat, installCount: 10, source: "example/skills",
              branch: "main", skillPathSHA: "ui-test", tags: ["Development"],
              createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
    }
}

private struct UITestAccount: AccountRepositoryProtocol {
    func signInURL(provider: SignInProvider, redirectURI: String, codeChallenge: String, state: String) -> URL {
        URL(string: "https://example.invalid/sign-in/\(provider.rawValue)")!
    }

    func exchange(code: String, codeVerifier: String, redirectURI: String) async throws -> AccountSession {
        UITestSessionStore.session
    }

    func refresh(refreshToken: String) async throws -> AccountSession { UITestSessionStore.session }
    func signOut(accessToken: String) async throws {}
    func deleteAccount(accessToken: String) async throws {}

    func pushFavorites(_ changes: [LocalFavorite], accessToken: String) async throws -> [FavoriteChangeResult] {
        changes.map { change in
            FavoriteChangeResult(skillID: change.skillID, status: .applied, error: nil, record: RemoteFavorite(
                skillID: change.skillID, state: change.state, updatedAt: change.updatedAt, snapshot: change.snapshot
            ))
        }
    }

    func pullFavorites(cursor: Int?, accessToken: String) async throws -> FavoriteChangesPage {
        FavoriteChangesPage(records: [], cursor: cursor ?? 0, hasMore: false)
    }
}

private final class UITestSessionStore: AccountSessionStoring, @unchecked Sendable {
    static let session = AccountSession(
        accessToken: "ui-test-access", refreshToken: "ui-test-refresh", accessTokenExpiresAt: .distantFuture,
        identity: AccountIdentity(provider: .github, displayName: "Ada Lovelace", email: "ada@example.com")
    )

    private let lock = NSLock()
    private var session: AccountSession?

    init(signedIn: Bool) {
        session = signedIn ? Self.session : nil
    }

    func load() -> AccountSession? { lock.withLock { session } }
    func save(_ session: AccountSession) throws { lock.withLock { self.session = session } }
    func delete() { lock.withLock { session = nil } }
}

private struct UITestContent: SkillContentRepositoryProtocol {
    func fetchDirectory(for skill: Skill) async throws -> [SkillDirectoryEntry] {
        [SkillDirectoryEntry(path: "SKILL.md", isDirectory: false),
         SkillDirectoryEntry(path: "example.swift", isDirectory: false),
         SkillDirectoryEntry(path: "archive.zip", isDirectory: false)]
    }

    func fetchTextFile(for skill: Skill, relativePath: String) async throws -> String {
        if relativePath == "example.swift" { return "let greeting = \"Hello, world!\"" }
        return "# Skill guide\n\nBrowse, read, and save skills.\n\n## Workflow\n\n1. Read the instructions.\n2. Review the result."
    }

    func rawURL(for skill: Skill, relativePath: String) throws -> URL {
        URL(string: "https://example.com/\(relativePath)")!
    }
}

private actor UITestTranslation: TranslationRepositoryProtocol {
    private let failsAfterTwoRequests = ProcessInfo.processInfo.arguments.contains("--ui-translation-fails-after-two")
    private var requestCount = 0

    func validate(settings: TranslationSettings) async throws -> String { "Connection verified" }

    func translate(markdown: String, settings: TranslationSettings) async throws -> String {
        requestCount += 1
        if failsAfterTwoRequests && requestCount > 2 {
            throw URLError(.notConnectedToInternet)
        }
        let title = requestCount == 1 ? "Translated guide" : "Retranslated guide"
        return "# \(title)\n\nThis response verifies the translation UI workflow.\n\n## Translated workflow\n\n1. Translated step one.\n2. Translated step two."
    }
}
#endif
