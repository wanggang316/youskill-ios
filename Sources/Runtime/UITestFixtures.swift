#if DEBUG
import Foundation

extension AppContainer {
    @MainActor
    static func uiTesting() -> AppContainer {
        AppContainer(
            favoritesStore: FavoritesStore(),
            settingsStore: AppSettingsStore(),
            skillCatalogService: SkillCatalogService(repository: UITestCatalog()),
            skillContentService: SkillContentService(repository: UITestContent()),
            translationService: TranslationService(
                repository: UITestTranslation(),
                cache: DiskCache(namespace: "ui-test-translations")
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

    private func makeSkill(id: Int, name: String, stars: Int, heat: Int) -> Skill {
        Skill(id: id, name: name, description: "A sample skill for UI acceptance tests.",
              url: "https://github.com/example/skills", path: "skills/\(name)",
              starCount: stars, heatScore: heat, installCount: 10, source: "example/skills",
              branch: "main", skillPathSHA: "ui-test", tags: ["Development"],
              createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
    }
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

private struct UITestTranslation: TranslationRepositoryProtocol {
    func validate(settings: TranslationSettings) async throws -> String { "Connection verified" }

    func translate(markdown: String, settings: TranslationSettings) async throws -> String {
        "# Translated guide\n\nThis response verifies the translation UI workflow."
    }
}
#endif
