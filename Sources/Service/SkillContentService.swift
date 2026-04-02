import Foundation

struct SkillContentService: Sendable {
    private let repository: any SkillContentRepositoryProtocol

    init(repository: any SkillContentRepositoryProtocol) {
        self.repository = repository
    }

    func fetchDirectory(for skill: Skill) async throws -> [SkillDirectoryEntry] {
        try await repository.fetchDirectory(for: skill)
    }

    func fetchTextFile(for skill: Skill, relativePath: String) async throws -> String {
        try await repository.fetchTextFile(for: skill, relativePath: relativePath)
    }

    func rawURL(for skill: Skill, relativePath: String) throws -> URL {
        try repository.rawURL(for: skill, relativePath: relativePath)
    }
}
