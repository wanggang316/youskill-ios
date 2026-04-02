import Foundation
import Testing
@testable import YouSkill

@Suite(.serialized)
struct GitHubContentRepositoryTests {
    @Test
    func fetchDirectoryFiltersToSkillPathAndBuildsDirectories() async throws {
        let session = makeSession()
        let repository = GitHubContentRepository(
            httpClient: HTTPClient(session: session),
            directoryCache: DiskCache(namespace: UUID().uuidString),
            fileCache: DiskCache(namespace: UUID().uuidString)
        )

        let skill = Skill(
            id: 1,
            name: "find-skill",
            description: nil,
            url: "https://github.com/example/repo.git",
            path: "skills/find-skill",
            starCount: 0,
            heatScore: 0,
            installCount: 0,
            source: "example/repo",
            branch: "main",
            skillPathSHA: "abc",
            tags: [],
            createdAt: .now,
            updatedAt: .now
        )

        MockURLProtocol.register(url: "https://api.github.com/repos/example/repo/git/trees/main?recursive=1") { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
              "tree": [
                { "path": "README.md", "type": "blob" },
                { "path": "skills/find-skill/SKILL.md", "type": "blob" },
                { "path": "skills/find-skill/config/prompt.md", "type": "blob" },
                { "path": "skills/other/SKILL.md", "type": "blob" }
              ]
            }
            """
            return (response, Data(json.utf8))
        }

        let entries = try await repository.fetchDirectory(for: skill)

        #expect(entries.contains(SkillDirectoryEntry(path: "SKILL.md", isDirectory: false)))
        #expect(entries.contains(SkillDirectoryEntry(path: "config", isDirectory: true)))
        #expect(entries.contains(SkillDirectoryEntry(path: "config/prompt.md", isDirectory: false)))
        #expect(!entries.contains(SkillDirectoryEntry(path: "README.md", isDirectory: false)))
    }

    @Test
    func fetchTextFileUsesRawGitHubURL() async throws {
        let session = makeSession()
        let repository = GitHubContentRepository(
            httpClient: HTTPClient(session: session),
            directoryCache: DiskCache(namespace: UUID().uuidString),
            fileCache: DiskCache(namespace: UUID().uuidString)
        )

        let skill = Skill(
            id: 2,
            name: "find-skill",
            description: nil,
            url: "https://github.com/example/repo.git",
            path: "skills/find-skill",
            starCount: 0,
            heatScore: 0,
            installCount: 0,
            source: nil,
            branch: "main",
            skillPathSHA: "def",
            tags: [],
            createdAt: .now,
            updatedAt: .now
        )

        MockURLProtocol.register(url: "https://raw.githubusercontent.com/example/repo/main/skills/find-skill/SKILL.md") { request in
            #expect(
                request.url?.absoluteString == "https://raw.githubusercontent.com/example/repo/main/skills/find-skill/SKILL.md"
            )
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("# Skill".utf8))
        }

        let content = try await repository.fetchTextFile(for: skill, relativePath: "SKILL.md")
        #expect(content == "# Skill")
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
