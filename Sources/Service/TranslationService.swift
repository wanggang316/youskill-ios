import Foundation

struct TranslationService: Sendable {
    private let repository: any TranslationRepositoryProtocol
    private let cache: DiskCache

    init(
        repository: any TranslationRepositoryProtocol,
        cache: DiskCache = DiskCache(namespace: "translation-cache")
    ) {
        self.repository = repository
        self.cache = cache
    }

    func validate(settings: TranslationSettings) async throws -> String {
        guard settings.isComplete else {
            throw TranslationRepositoryError.incompleteSettings
        }
        return try await repository.validate(settings: settings)
    }

    func translate(markdown: String, skillID: Int, relativePath: String, settings: TranslationSettings) async throws -> String {
        let cacheKey = "translation|\(skillID)|\(relativePath)|\(settings.targetLanguage.rawValue)|\(settings.trimmedModel)|\(markdown.hashValue)"
        if let cached = await cache.loadText(for: cacheKey) {
            return cached
        }

        let translated = try await repository.translate(markdown: markdown, settings: settings)
        try await cache.store(text: translated, for: cacheKey)
        return translated
    }
}
