import Foundation

protocol SkillCatalogRepositoryProtocol: Sendable {
    func fetchSkills(query: SkillQuery) async throws -> SkillsPage
    func fetchCategories() async throws -> [SkillCategory]
    func fetchHotRepositories() async throws -> [FeaturedRepository]
}

struct SkillCatalogRepository: SkillCatalogRepositoryProtocol, Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchSkills(query: SkillQuery) async throws -> SkillsPage {
        var components = URLComponents(url: AppConfiguration.apiBaseURL.appending(path: "/api/public/skills"), resolvingAgainstBaseURL: false)
        var items = [
            URLQueryItem(name: "skip", value: String(query.skip)),
            URLQueryItem(name: "limit", value: String(query.pageSize)),
            URLQueryItem(name: "sort_order", value: "desc")
        ]

        if let sortBy = query.sortOption.apiValue {
            items.append(URLQueryItem(name: "sort_by", value: sortBy))
        }
        if !query.trimmedSearchText.isEmpty {
            items.append(URLQueryItem(name: "search", value: query.trimmedSearchText))
        }
        switch query.scope {
        case .all:
            break
        case let .category(category):
            items.append(URLQueryItem(name: "tag_id", value: String(category.id)))
        case let .repository(repository):
            items.append(URLQueryItem(name: "source", value: repository.name))
        }
        components?.queryItems = items

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data = try await httpClient.send(request)
        return try AppJSONCoders.decoder.decode(SkillsPage.self, from: data)
    }

    func fetchCategories() async throws -> [SkillCategory] {
        let response: CategoriesResponse = try await fetchCatalog(path: "tags/summary")
        return response.tags
    }

    func fetchHotRepositories() async throws -> [FeaturedRepository] {
        let response: RepositoriesResponse = try await fetchCatalog(path: "featured-repos")
        return response.items.filter { $0.enabled && $0.type == "hot" }
    }

    private func fetchCatalog<T: Decodable>(path: String) async throws -> T {
        let url = AppConfiguration.apiBaseURL.appending(path: "/api/public/\(path)")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await httpClient.send(request)
        return try AppJSONCoders.decoder.decode(T.self, from: data)
    }

    private struct CategoriesResponse: Decodable {
        let tags: [SkillCategory]
    }

    private struct RepositoriesResponse: Decodable {
        let items: [FeaturedRepository]
    }

}
