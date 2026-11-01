import Foundation
import Testing
@testable import YouSkill

@Suite(.serialized)
struct SkillCatalogRepositoryTests {
    @Test
    func fetchSkillsParsesPayloadAndBuildsRequest() async throws {
        let session = makeSession()
        let repository = SkillCatalogRepository(httpClient: HTTPClient(session: session))

        let expectedURL = "https://api.youskill.cc/api/public/skills?skip=0&limit=30&sort_order=desc&sort_by=install_count&search=agent"
        MockURLProtocol.register(url: expectedURL) { request in
            let url = try #require(request.url)
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            #expect(request.value(forHTTPHeaderField: "X-API-Key") == nil)
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
                  "updated_at": "2026-04-01T12:00:00.000000"
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
        #expect(page.skills.first?.updatedAt == page.skills.first?.createdAt)
    }

    @Test
    func categoryAndRepositoryFiltersAreExclusive() async throws {
        let repository = SkillCatalogRepository(httpClient: HTTPClient(session: makeSession()))
        let category = SkillCategory(id: 7, name: "design", icon: nil, skillCount: 2)
        let featured = FeaturedRepository(id: 1, name: "team/tools", icon: nil, skillCount: 2, starCount: 120, enabled: true, type: "hot")
        for (scope, suffix) in [(CatalogScope.category(category), "tag_id=7"), (.repository(featured), "source=team/tools")] {
            let url = "https://api.youskill.cc/api/public/skills?skip=30&limit=30&sort_order=desc&sort_by=star_count&\(suffix)"
            MockURLProtocol.register(url: url) { request in
                let actual = try #require(request.url)
                let items = URLComponents(url: actual, resolvingAgainstBaseURL: false)?.queryItems ?? []
                #expect(items.filter { $0.name == "tag_id" || $0.name == "source" }.count == 1)
                let response = HTTPURLResponse(url: actual, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(#"{"skills":[],"total":0,"page":2,"page_size":30}"#.utf8))
            }
            _ = try await repository.fetchSkills(query: SkillQuery(sortOption: .starCount, page: 2, scope: scope))
        }
    }

    @Test
    func navigationDecodesIconsStarsAndFiltersRepositories() async throws {
        let repository = SkillCatalogRepository(httpClient: HTTPClient(session: makeSession()))
        let payloads = [
            ("tags/summary", #"{"tags":[{"id":7,"name":"design","icon":"lucide:pen","skill_count":2}],"total":1}"#),
            ("featured-repos", #"{"items":[{"id":1,"name":"team/tools","icon":"lucide:star","skill_count":2,"star_count":120,"enabled":true,"type":"hot"},{"id":2,"name":"team/disabled","skill_count":0,"enabled":false,"type":"hot"},{"id":3,"name":"team/official","skill_count":0,"enabled":true,"type":"official"}],"total":3}"#)
        ]
        for (path, json) in payloads {
            MockURLProtocol.register(url: "https://api.youskill.cc/api/public/\(path)") { request in
                let url = try #require(request.url)
                #expect(request.value(forHTTPHeaderField: "X-API-Key") == nil)
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
            }
        }
        let categories = try await repository.fetchCategories()
        #expect(categories.first?.icon == "lucide:pen")
        let repos = try await repository.fetchHotRepositories()
        #expect(repos.count == 1)
        #expect(repos.first?.starCount == 120)
        #expect(repos.first?.icon == "lucide:star")
    }

    @Test(arguments: [
        "2026-04-01T12:00:00Z",
        "2026-04-01T12:00:00.000000Z",
        "2026-04-01T12:00:00",
        "2026-04-01T12:00:00.000000",
        "2026-04-01T14:00:00+02:00"
    ])
    func catalogTimestampsPreserveUTCInstant(_ timestamp: String) throws {
        let data = try JSONEncoder().encode(timestamp)
        let date = try AppJSONCoders.decoder.decode(Date.self, from: data)
        let expected = try #require(ISO8601Formatters.makeBasic().date(from: "2026-04-01T12:00:00Z"))
        #expect(date == expected)
    }

    @Test(arguments: ["invalid", "2026-04-01", "2026-04-01T12:00:00garbage"])
    func malformedTimestampsAreRejected(_ timestamp: String) throws {
        let data = try JSONEncoder().encode(timestamp)
        #expect(throws: DecodingError.self) {
            try AppJSONCoders.decoder.decode(Date.self, from: data)
        }
    }

    @Test
    func fetchSkillReturnsNilWhenTheSkillLeftTheMarketplace() async throws {
        let repository = SkillCatalogRepository(httpClient: HTTPClient(session: makeSession()))
        MockURLProtocol.register(url: "https://api.youskill.cc/api/public/skills/404") { request in
            (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
             Data(#"{"detail": "Skill not found"}"#.utf8))
        }
        MockURLProtocol.register(url: "https://api.youskill.cc/api/public/skills/7") { request in
            let json = """
            {"id": 7, "name": "live", "description": null, "url": null, "path": null, "star_count": 1,
             "heat_score": 0, "install_count": 0, "source": "a/b", "branch": null, "skill_path_sha": null,
             "tags": [], "created_at": "2026-04-01T12:00:00Z", "updated_at": "2026-04-01T12:00:00Z"}
            """
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(json.utf8))
        }

        #expect(try await repository.fetchSkill(id: 404) == nil)
        #expect(try await repository.fetchSkill(id: 7)?.name == "live")
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
