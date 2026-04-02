import Foundation
import Testing
@testable import YouSkill

@Suite(.serialized)
struct SkillCatalogRepositoryTests {
    @Test
    func fetchSkillsParsesPayloadAndBuildsRequest() async throws {
        let session = makeSession()
        let repository = SkillCatalogRepository(httpClient: HTTPClient(session: session))

        let expectedURL = "https://api.youskill.cc/api/skills?skip=0&limit=30&sort_order=desc&sort_by=install_count&search=agent"
        MockURLProtocol.register(url: expectedURL) { request in
            let url = try #require(request.url)
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            #expect(request.value(forHTTPHeaderField: "X-API-Key") == AppConfiguration.skillsAPIKey)
            #expect(queryItems?.first(where: { $0.name == "search" })?.value == "agent")
            #expect(queryItems?.first(where: { $0.name == "sort_by" })?.value == "install_count")

            let json = """
            {
              "skills": [
                {
                  "id": 1,
                  "name": "find-skill",
                  "description": "Search for skills",
                  "url": "https://github.com/example/repo.git",
                  "path": "skills/find-skill",
                  "star_count": 100,
                  "heat_score": 5,
                  "install_count": 80,
                  "source": "example/repo",
                  "branch": "main",
                  "skill_path_sha": "abc",
                  "tags": ["search"],
                  "created_at": "2026-04-01T12:00:00.000000Z",
                  "updated_at": "2026-04-01T12:00:00.000000Z"
                }
              ],
              "total": 1,
              "page": 1,
              "page_size": 30
            }
            """
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let page = try await repository.fetchSkills(
            query: SkillQuery(searchText: "agent", sortOption: .installCount, page: 1, pageSize: 30)
        )

        #expect(page.total == 1)
        #expect(page.skills.first?.name == "find-skill")
        #expect(page.skills.first?.starCount == 100)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
