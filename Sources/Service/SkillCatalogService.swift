import Foundation

struct SkillCatalogService: Sendable {
    private let repository: any SkillCatalogRepositoryProtocol

    init(repository: any SkillCatalogRepositoryProtocol) {
        self.repository = repository
    }

    func fetchSkills(query: SkillQuery) async throws -> SkillsPage {
        try await repository.fetchSkills(query: query)
    }
}
