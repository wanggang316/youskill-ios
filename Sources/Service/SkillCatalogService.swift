import Foundation

struct SkillCatalogService: Sendable {
    private let repository: any SkillCatalogRepositoryProtocol

    init(repository: any SkillCatalogRepositoryProtocol) {
        self.repository = repository
    }

    func fetchSkills(query: SkillQuery) async throws -> SkillsPage {
        try await repository.fetchSkills(query: query)
    }

    func fetchCategories() async throws -> [SkillCategory] {
        try await repository.fetchCategories()
    }

    func fetchHotRepositories() async throws -> [FeaturedRepository] {
        try await repository.fetchHotRepositories()
    }

}
