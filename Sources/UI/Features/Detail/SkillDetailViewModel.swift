import Foundation
import Observation

@MainActor
@Observable
final class SkillDetailViewModel {
    let skill: Skill

    private let contentService: SkillContentService
    private let translationService: TranslationService
    private let translationSettings: @MainActor () -> TranslationSettings
    /// Bumped whenever the open file changes so late translation results for another file are dropped.
    private var fileGeneration = 0
    private var lastTranslationWasForced = false

    private(set) var directoryEntries: [SkillDirectoryEntry] = []
    private(set) var fileTree: [FileTreeNode] = []
    private(set) var activePath: String?
    private(set) var originalContent: String = ""
    private(set) var translatedContent: String?
    private(set) var originalDescription: String?
    private(set) var translatedDescription: String?
    private var alignedSegments: [BilingualSegment] = []
    private(set) var rawOriginalMarkdown: String = ""
    private(set) var translationView: TranslationView = .original
    private(set) var fileKind: SkillFileKind = .markdown
    private(set) var rawFileURL: URL?
    private(set) var browserFileURL: URL?
    private(set) var isLoading = false
    private(set) var isLoadingFile = false
    private(set) var isTranslating = false
    private(set) var errorMessage: String?
    private(set) var translationErrorMessage: String?
    private(set) var missingTranslationFields: [TranslationSettingField] = []
    private(set) var didLoad = false
    var isDrawerOpen = false
    var needsTranslationSettings = false

    init(
        skill: Skill,
        contentService: SkillContentService,
        translationService: TranslationService,
        translationSettings: @escaping @MainActor () -> TranslationSettings
    ) {
        self.skill = skill
        self.contentService = contentService
        self.translationService = translationService
        self.translationSettings = translationSettings
    }

    var hasTranslation: Bool {
        translatedContent != nil
    }

    /// The view actually rendered. Without a translation the reader always shows the original.
    var effectiveTranslationView: TranslationView {
        hasTranslation ? translationView : .original
    }

    var displayedContent: String {
        if effectiveTranslationView == .translation, let translatedContent {
            return translatedContent
        }
        return originalContent
    }

    var displayedDescription: String? {
        if effectiveTranslationView == .translation {
            return translatedDescription ?? originalDescription
        }
        return originalDescription
    }

    /// Only shown under the original description in bilingual view.
    var secondaryDescription: String? {
        guard effectiveTranslationView == .bilingual, translatedDescription != originalDescription else { return nil }
        return translatedDescription
    }

    var bilingualSegments: [BilingualSegment]? {
        effectiveTranslationView == .bilingual ? alignedSegments : nil
    }

    var displayTitle: String {
        skill.name
    }

    var canTranslate: Bool {
        fileKind.supportsTranslation && !rawOriginalMarkdown.isEmpty
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let entries = try await contentService.fetchDirectory(for: skill)
            directoryEntries = entries
            fileTree = FileTreeBuilder.build(from: entries)
            let firstFile = entries.first(where: { !$0.isDirectory && $0.path == "SKILL.md" })
                ?? entries.first(where: { !$0.isDirectory })

            if let file = firstFile {
                await loadFile(at: file.path)
            } else {
                errorMessage = L10n.string("detail.no_readable_files")
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadFile(at path: String) async {
        fileGeneration += 1
        let generation = fileGeneration
        activePath = path
        fileKind = SkillFileKind(path: path)
        translatedContent = nil
        translatedDescription = nil
        alignedSegments = []
        translationView = .original
        translationErrorMessage = nil
        isTranslating = false
        rawFileURL = try? contentService.rawURL(for: skill, relativePath: path)
        browserFileURL = skill.browserURL(for: path)
        errorMessage = nil
        rawOriginalMarkdown = ""
        originalDescription = nil

        if fileKind == .image || fileKind == .unsupported {
            originalContent = ""
            return
        }

        originalContent = ""
        isLoadingFile = true
        defer { isLoadingFile = false }

        do {
            let fetchedContent = try await contentService.fetchTextFile(for: skill, relativePath: path)
            guard generation == fileGeneration else { return }
            if fileKind == .markdown {
                rawOriginalMarkdown = fetchedContent
                let parsed = MarkdownFrontmatterParser.parse(fetchedContent)
                originalDescription = parsed.frontmatterDescription
                originalContent = parsed.body
            } else {
                originalContent = fetchedContent
            }
        } catch {
            guard generation == fileGeneration else { return }
            originalContent = ""
            errorMessage = error.localizedDescription
        }

        await restoreCachedTranslation(generation: generation)
    }

    /// First translation of the open file. The view follows the global display mode.
    func translate() async {
        guard !hasTranslation else { return }
        await performTranslation(force: false)
    }

    /// Skips the cache and keeps the current view.
    func retranslate() async {
        await performTranslation(force: true)
    }

    func retryTranslation() async {
        await performTranslation(force: lastTranslationWasForced)
    }

    /// Changes only this page's in-memory view; settings are untouched.
    func selectTranslationView(_ view: TranslationView) {
        guard hasTranslation, !isTranslating else { return }
        translationView = view
    }

    func dismissTranslationError() {
        translationErrorMessage = nil
    }

    private func restoreCachedTranslation(generation: Int) async {
        guard canTranslate, let activePath else { return }
        let settings = translationSettings()
        guard let cached = await translationService.cachedTranslation(
            markdown: rawOriginalMarkdown,
            skillID: skill.id,
            relativePath: activePath,
            settings: settings
        ), generation == fileGeneration, !hasTranslation else { return }
        applyTranslation(cached)
        translationView = TranslationView(settings.displayMode)
    }

    private func performTranslation(force: Bool) async {
        guard canTranslate, !isTranslating, let activePath else { return }

        let settings = translationSettings()
        guard settings.isComplete else {
            missingTranslationFields = settings.missingFields
            needsTranslationSettings = true
            return
        }

        let generation = fileGeneration
        let isFirstTranslation = !hasTranslation
        lastTranslationWasForced = force
        isTranslating = true
        translationErrorMessage = nil

        do {
            let translated = try await translationService.translate(
                markdown: rawOriginalMarkdown,
                skillID: skill.id,
                relativePath: activePath,
                settings: settings,
                force: force
            )
            guard generation == fileGeneration else { return }
            applyTranslation(translated)
            if isFirstTranslation {
                translationView = TranslationView(settings.displayMode)
            }
        } catch {
            guard generation == fileGeneration else { return }
            // Keep the original and any earlier translation on screen.
            translationErrorMessage = TranslationValidationErrorFormatter.message(for: error)
        }

        isTranslating = false
    }

    private func applyTranslation(_ translated: String) {
        let parsed = MarkdownFrontmatterParser.parse(translated)
        translatedDescription = parsed.frontmatterDescription
        translatedContent = parsed.body
        alignedSegments = BilingualMarkdownAligner.segments(original: originalContent, translated: parsed.body)
    }
}
