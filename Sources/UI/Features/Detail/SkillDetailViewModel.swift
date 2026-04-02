import Foundation
import Observation

@MainActor
@Observable
final class SkillDetailViewModel {
    let skill: Skill

    private let contentService: SkillContentService
    private let translationService: TranslationService

    private(set) var directoryEntries: [SkillDirectoryEntry] = []
    private(set) var fileTree: [FileTreeNode] = []
    private(set) var activePath: String?
    private(set) var originalContent: String = ""
    private(set) var translatedContent: String?
    private(set) var originalDescription: String?
    private(set) var translatedDescription: String?
    private(set) var rawOriginalMarkdown: String = ""
    private(set) var isShowingTranslated = false
    private(set) var fileKind: SkillFileKind = .markdown
    private(set) var rawFileURL: URL?
    private(set) var browserFileURL: URL?
    private(set) var isLoading = false
    private(set) var isTranslating = false
    private(set) var errorMessage: String?
    private(set) var didLoad = false
    var isDrawerOpen = false
    var needsTranslationSettings = false

    init(skill: Skill, contentService: SkillContentService, translationService: TranslationService) {
        self.skill = skill
        self.contentService = contentService
        self.translationService = translationService
    }

    var displayedContent: String {
        if isShowingTranslated, let translatedContent {
            return translatedContent
        }
        return originalContent
    }

    var displayedDescription: String? {
        if isShowingTranslated {
            return translatedDescription
        }
        return originalDescription
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
        activePath = path
        fileKind = SkillFileKind(path: path)
        translatedContent = nil
        translatedDescription = nil
        isShowingTranslated = false
        rawFileURL = try? contentService.rawURL(for: skill, relativePath: path)
        browserFileURL = skill.browserURL(for: path)
        errorMessage = nil
        rawOriginalMarkdown = ""
        originalDescription = nil

        if fileKind == .image || fileKind == .unsupported {
            originalContent = ""
            return
        }

        do {
            let fetchedContent = try await contentService.fetchTextFile(for: skill, relativePath: path)
            if fileKind == .markdown {
                rawOriginalMarkdown = fetchedContent
                let parsed = MarkdownFrontmatterParser.parse(fetchedContent)
                originalDescription = parsed.frontmatterDescription
                originalContent = parsed.body
            } else {
                originalContent = fetchedContent
            }
        } catch {
            originalContent = ""
            errorMessage = error.localizedDescription
        }
    }

    func toggleTranslation(using settings: TranslationSettings) async {
        guard canTranslate, let activePath else { return }

        if isShowingTranslated {
            isShowingTranslated = false
            return
        }

        guard settings.isComplete else {
            needsTranslationSettings = true
            return
        }

        if translatedContent != nil {
            isShowingTranslated = true
            return
        }

        isTranslating = true
        errorMessage = nil

        do {
            let translated = try await translationService.translate(
                markdown: rawOriginalMarkdown,
                skillID: skill.id,
                relativePath: activePath,
                settings: settings
            )
            let parsed = MarkdownFrontmatterParser.parse(translated)
            translatedDescription = parsed.frontmatterDescription
            translatedContent = parsed.body
            isShowingTranslated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isTranslating = false
    }
}
