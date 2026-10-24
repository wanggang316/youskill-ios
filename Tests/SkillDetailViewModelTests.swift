import Foundation
import Testing
@testable import YouSkill

@MainActor
@Suite(.serialized)
struct SkillDetailViewModelTests {
    @Test(arguments: TranslationDisplayMode.allCases)
    func firstTranslationFollowsGlobalDisplayMode(_ mode: TranslationDisplayMode) async {
        let context = Context(mode: mode)
        await context.viewModel.load()

        await context.viewModel.translate()

        #expect(context.viewModel.translationView == TranslationView(mode))
        #expect(context.viewModel.translatedContent == "# 指南\n\n阅读说明。")
    }

    @Test
    func bilingualViewStacksBlocksAndTranslationShowsOnlyTranslatedText() async {
        let context = Context(mode: .bilingual)
        await context.viewModel.load()
        await context.viewModel.translate()

        #expect(context.viewModel.bilingualSegments == [
            .heading(level: 1, original: "Guide", translated: "指南"),
            .stacked(original: "Read the instructions.", translated: "阅读说明。")
        ])
        #expect(context.viewModel.displayedContent == "# Guide\n\nRead the instructions.")

        context.viewModel.selectTranslationView(.translation)

        #expect(context.viewModel.bilingualSegments == nil)
        #expect(context.viewModel.displayedContent == "# 指南\n\n阅读说明。")
    }

    @Test
    func switchingViewsDoesNotWriteSettings() async {
        let context = Context(mode: .translation)
        await context.viewModel.load()
        await context.viewModel.translate()

        for view in [TranslationView.original, .bilingual, .translation, .original] {
            context.viewModel.selectTranslationView(view)
            #expect(context.viewModel.translationView == view)
        }

        #expect(context.settings.translationSettings.displayMode == .translation)
        #expect(await context.translations.callCount == 1)
    }

    @Test
    func retranslateSkipsCacheAndKeepsCurrentView() async {
        let context = Context(mode: .bilingual, results: [.success("# 指南\n\n阅读说明。"), .success("# 新指南\n\n新的说明。")])
        await context.viewModel.load()
        await context.viewModel.translate()
        context.viewModel.selectTranslationView(.original)

        await context.viewModel.retranslate()

        #expect(await context.translations.callCount == 2)
        #expect(context.viewModel.translationView == .original)
        #expect(context.viewModel.translatedContent == "# 新指南\n\n新的说明。")
    }

    @Test
    func failedTranslationKeepsOriginalAndOffersRetry() async {
        let context = Context(mode: .bilingual, results: [.failure(URLError(.notConnectedToInternet)), .success("# 指南")])
        await context.viewModel.load()

        await context.viewModel.translate()

        #expect(context.viewModel.errorMessage == nil)
        #expect(context.viewModel.translationErrorMessage != nil)
        #expect(context.viewModel.displayedContent == "# Guide\n\nRead the instructions.")
        #expect(!context.viewModel.hasTranslation)

        await context.viewModel.retryTranslation()

        #expect(context.viewModel.translationErrorMessage == nil)
        #expect(context.viewModel.hasTranslation)
    }

    @Test
    func failedRetranslationKeepsExistingTranslationAndView() async {
        let context = Context(mode: .translation, results: [.success("# 指南\n\n阅读说明。"), .failure(URLError(.timedOut))])
        await context.viewModel.load()
        await context.viewModel.translate()

        await context.viewModel.retranslate()

        #expect(context.viewModel.errorMessage == nil)
        #expect(context.viewModel.translationErrorMessage != nil)
        #expect(context.viewModel.translationView == .translation)
        #expect(context.viewModel.displayedContent == "# 指南\n\n阅读说明。")
        #expect(!context.viewModel.isTranslating)
    }

    @Test
    func switchingFilesResetsToOriginalAndRestoresCachedTranslations() async {
        let context = Context(mode: .translation)
        await context.viewModel.load()
        await context.viewModel.translate()

        await context.viewModel.loadFile(at: "docs/other.md")

        #expect(context.viewModel.translationView == .original)
        #expect(!context.viewModel.hasTranslation)

        context.settings.updateDisplayMode(.bilingual)
        await context.viewModel.loadFile(at: "SKILL.md")

        #expect(context.viewModel.hasTranslation)
        #expect(context.viewModel.translationView == .bilingual)
        #expect(await context.translations.callCount == 1)
    }

    @Test
    func changingDisplayModeDoesNotChangeTheOpenView() async {
        let context = Context(mode: .bilingual)
        await context.viewModel.load()
        await context.viewModel.translate()

        context.settings.updateDisplayMode(.translation)

        #expect(context.viewModel.translationView == .bilingual)
    }

    @Test
    func missingSettingsListFieldsWithoutRequesting() async {
        let context = Context(mode: .bilingual, configured: false)
        await context.viewModel.load()

        await context.viewModel.translate()

        #expect(context.viewModel.needsTranslationSettings)
        #expect(context.viewModel.missingTranslationFields == [.apiKey, .model])
        #expect(await context.translations.callCount == 0)
    }

    @Test
    func viewSelectionNeedsATranslation() async {
        let context = Context(mode: .bilingual)
        await context.viewModel.load()

        context.viewModel.selectTranslationView(.translation)

        #expect(context.viewModel.translationView == .original)
    }
}

@MainActor
private struct Context {
    let settings: AppSettingsStore
    let translations: ScriptedTranslationRepository
    let viewModel: SkillDetailViewModel

    init(
        mode: TranslationDisplayMode,
        configured: Bool = true,
        results: [Result<String, Error>] = [.success("# 指南\n\n阅读说明。")]
    ) {
        let store = AppSettingsStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        store.update(TranslationSettings(
            baseURL: "https://example.com/v1",
            apiKey: configured ? "key" : "",
            model: configured ? "model" : "",
            targetLanguage: .chinese,
            displayMode: mode
        ))
        let repository = ScriptedTranslationRepository(results: results)
        settings = store
        translations = repository
        viewModel = SkillDetailViewModel(
            skill: Skill(
                id: Int.random(in: 1 ... Int.max),
                name: "demo",
                description: nil,
                url: "https://github.com/octo-org/demo-skill",
                path: "skills/demo",
                starCount: 0,
                heatScore: 0,
                installCount: 0,
                source: "octo-org/demo-skill",
                branch: "main",
                skillPathSHA: nil,
                tags: [],
                createdAt: .now,
                updatedAt: .now
            ),
            contentService: SkillContentService(repository: StaticContentRepository()),
            translationService: TranslationService(
                repository: repository,
                cache: DiskCache(namespace: "tests-\(UUID().uuidString)")
            ),
            translationSettings: { store.translationSettings }
        )
    }
}

private struct StaticContentRepository: SkillContentRepositoryProtocol {
    func fetchDirectory(for skill: Skill) async throws -> [SkillDirectoryEntry] {
        [SkillDirectoryEntry(path: "SKILL.md", isDirectory: false),
         SkillDirectoryEntry(path: "docs/other.md", isDirectory: false)]
    }

    func fetchTextFile(for skill: Skill, relativePath: String) async throws -> String {
        relativePath == "SKILL.md" ? "# Guide\n\nRead the instructions." : "Other file."
    }

    func rawURL(for skill: Skill, relativePath: String) throws -> URL {
        URL(string: "https://example.com/\(relativePath)")!
    }
}
