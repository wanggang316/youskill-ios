import Foundation
import Testing
@testable import YouSkill

@Suite
struct TranslationServiceTests {
    private let settings = TranslationSettings(baseURL: "https://example.com/v1", apiKey: "k", model: "m", targetLanguage: .chinese)

    @Test
    func cachedTranslationIsReusedUnlessForced() async throws {
        let repository = ScriptedTranslationRepository(results: [.success("# 一"), .success("# 二")])
        let service = TranslationService(repository: repository, cache: DiskCache(namespace: "tests-\(UUID().uuidString)"))

        let first = try await service.translate(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: settings)
        let cached = try await service.translate(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: settings)
        let forced = try await service.translate(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: settings, force: true)
        let restored = await service.cachedTranslation(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: settings)

        #expect(first == "# 一")
        #expect(cached == "# 一")
        #expect(forced == "# 二")
        #expect(restored == "# 二")
        #expect(await repository.callCount == 2)
    }

    @Test
    func unchangedResultFailsAndIsNotCached() async throws {
        let repository = ScriptedTranslationRepository(results: [.success("  # One\n")])
        let service = TranslationService(repository: repository, cache: DiskCache(namespace: "tests-\(UUID().uuidString)"))

        await #expect(throws: TranslationRepositoryError.unchangedTranslation) {
            try await service.translate(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: settings)
        }
        #expect(await service.cachedTranslation(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: settings) == nil)
    }

    @Test
    func cacheKeyIncludesModelAndLanguage() async throws {
        let repository = ScriptedTranslationRepository(results: [.success("# 一")])
        let service = TranslationService(repository: repository, cache: DiskCache(namespace: "tests-\(UUID().uuidString)"))
        _ = try await service.translate(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: settings)

        var otherLanguage = settings
        otherLanguage.targetLanguage = .japanese
        var otherModel = settings
        otherModel.model = "other"

        #expect(await service.cachedTranslation(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: otherLanguage) == nil)
        #expect(await service.cachedTranslation(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: otherModel) == nil)
        #expect(await service.cachedTranslation(markdown: "# One", skillID: 1, relativePath: "SKILL.md", settings: settings) == "# 一")
    }
}

/// Returns scripted results in order; the last result repeats.
actor ScriptedTranslationRepository: TranslationRepositoryProtocol {
    private var results: [Result<String, Error>]
    private(set) var callCount = 0

    init(results: [Result<String, Error>]) {
        self.results = results
    }

    func validate(settings: TranslationSettings) async throws -> String { "OK" }

    func translate(markdown: String, settings: TranslationSettings) async throws -> String {
        callCount += 1
        let result = results.count > 1 ? results.removeFirst() : results[0]
        return try result.get()
    }
}
