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

    /// Returns a stored translation without calling the model. Used to restore a file's translation on open.
    func cachedTranslation(markdown: String, skillID: Int, relativePath: String, settings: TranslationSettings) async -> String? {
        let key = cacheKey(markdown: markdown, skillID: skillID, relativePath: relativePath, settings: settings)
        guard let cached = await cache.loadText(for: key), !Self.isUnchanged(cached, from: markdown) else {
            return nil
        }
        return cached
    }

    /// `force` skips the cache read and overwrites the cached translation on success.
    func translate(
        markdown: String,
        skillID: Int,
        relativePath: String,
        settings: TranslationSettings,
        force: Bool = false
    ) async throws -> String {
        if !force, let cached = await cachedTranslation(
            markdown: markdown,
            skillID: skillID,
            relativePath: relativePath,
            settings: settings
        ) {
            return cached
        }

        let translated = try await repository.translate(markdown: markdown, settings: settings)
        guard !Self.isUnchanged(translated, from: markdown) else {
            throw TranslationRepositoryError.unchangedTranslation
        }
        let key = cacheKey(markdown: markdown, skillID: skillID, relativePath: relativePath, settings: settings)
        try await cache.store(text: translated, for: key)
        return translated
    }

    // DiskCache hashes the whole key with SHA-256, so the source text itself keeps the key stable across launches.
    private func cacheKey(markdown: String, skillID: Int, relativePath: String, settings: TranslationSettings) -> String {
        "translation|v2|\(skillID)|\(relativePath)|\(settings.targetLanguage.rawValue)|\(settings.trimmedModel)|\(markdown)"
    }

    private static func isUnchanged(_ translated: String, from markdown: String) -> Bool {
        translated.trimmingCharacters(in: .whitespacesAndNewlines) == markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
