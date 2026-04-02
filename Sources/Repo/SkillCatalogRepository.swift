import Foundation

protocol SkillCatalogRepositoryProtocol: Sendable {
    func fetchSkills(query: SkillQuery) async throws -> SkillsPage
}

struct SkillCatalogRepository: SkillCatalogRepositoryProtocol, Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchSkills(query: SkillQuery) async throws -> SkillsPage {
        var components = URLComponents(url: AppConfiguration.apiBaseURL.appending(path: "/api/skills"), resolvingAgainstBaseURL: false)
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
        components?.queryItems = items

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue(AppConfiguration.skillsAPIKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data = try await httpClient.send(request)
        return try AppJSONCoders.decoder.decode(SkillsPage.self, from: data)
    }
}
