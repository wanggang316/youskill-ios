import Foundation

protocol SkillContentRepositoryProtocol: Sendable {
    func fetchDirectory(for skill: Skill) async throws -> [SkillDirectoryEntry]
    func fetchTextFile(for skill: Skill, relativePath: String) async throws -> String
    func rawURL(for skill: Skill, relativePath: String) throws -> URL
}

struct GitHubReference: Equatable, Sendable {
    let owner: String
    let repository: String

    init?(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: ".git", with: "")

        if cleaned.contains("github.com/"), let url = URL(string: cleaned),
           let host = url.host, host.contains("github.com") {
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count >= 2 else { return nil }
            owner = parts[0]
            repository = parts[1]
            return
        }

        let parts = cleaned.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return nil }
        owner = parts[0]
        repository = parts[1]
    }
}

private struct GitTreeResponse: Codable {
    let tree: [GitTreeEntry]
}

private struct GitTreeEntry: Codable {
    let path: String
    let type: String
}

struct GitHubContentRepository: SkillContentRepositoryProtocol, Sendable {
    private let httpClient: HTTPClient
    private let directoryCache: DiskCache
    private let fileCache: DiskCache

    init(
        httpClient: HTTPClient = HTTPClient(),
        directoryCache: DiskCache = DiskCache(namespace: "directory-cache"),
        fileCache: DiskCache = DiskCache(namespace: "file-cache")
    ) {
        self.httpClient = httpClient
        self.directoryCache = directoryCache
        self.fileCache = fileCache
    }

    func fetchDirectory(for skill: Skill) async throws -> [SkillDirectoryEntry] {
        let cacheKey = "dir|\(skill.id)|\(skill.skillPathSHA ?? skill.resolvedBranch)|\(skill.resolvedPath)"
        if let cached: [SkillDirectoryEntry] = await directoryCache.loadJSON([SkillDirectoryEntry].self, for: cacheKey) {
            return cached
        }

        let reference = try resolveReference(for: skill)
        let url = URL(string: "https://api.github.com/repos/\(reference.owner)/\(reference.repository)/git/trees/\(skill.resolvedBranch.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? skill.resolvedBranch)?recursive=1")!

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("YouSkill-iOS", forHTTPHeaderField: "User-Agent")

        let data = try await httpClient.send(request)
        let payload = try AppJSONCoders.decoder.decode(GitTreeResponse.self, from: data)

        let basePath = skill.resolvedPath
        let prefix = basePath.isEmpty ? "" : "\(basePath)/"

        let files = payload.tree
            .filter { entry in
                entry.type == "blob" && (basePath.isEmpty || entry.path.hasPrefix(prefix))
            }
            .map { entry -> SkillDirectoryEntry in
                let relative = basePath.isEmpty ? entry.path : String(entry.path.dropFirst(prefix.count))
                return SkillDirectoryEntry(path: relative, isDirectory: false)
            }

        let directories = Set(files.flatMap { file in
            let parts = file.path.split(separator: "/").map(String.init)
            guard parts.count > 1 else { return [String]() }
            return (1 ..< parts.count).map { parts.prefix($0).joined(separator: "/") }
        }).map { SkillDirectoryEntry(path: $0, isDirectory: true) }

        let entries = (directories + files).sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }

        try await directoryCache.storeJSON(entries, for: cacheKey)
        return entries
    }

    func fetchTextFile(for skill: Skill, relativePath: String) async throws -> String {
        let cacheVersion = skill.skillPathSHA ?? skill.resolvedBranch
        let cacheKey = "file|\(skill.id)|\(cacheVersion)|\(relativePath)"
        if let cached = await fileCache.loadText(for: cacheKey) {
            return cached
        }

        let url = try rawURL(for: skill, relativePath: relativePath)
        var request = URLRequest(url: url)
        request.setValue("YouSkill-iOS", forHTTPHeaderField: "User-Agent")

        let data = try await httpClient.send(request)
        guard let text = String(data: data, encoding: .utf8) else {
            throw HTTPClientError.emptyResponse
        }

        try await fileCache.store(text: text, for: cacheKey)
        return text
    }

    func rawURL(for skill: Skill, relativePath: String) throws -> URL {
        let reference = try resolveReference(for: skill)
        let basePath = skill.resolvedPath
        let relative = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let combinedPath = [basePath, relative]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        let encodedPath = combinedPath
            .split(separator: "/")
            .map { component in
                String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(component)
            }
            .joined(separator: "/")

        guard let url = URL(string: "https://raw.githubusercontent.com/\(reference.owner)/\(reference.repository)/\(skill.resolvedBranch)/\(encodedPath)") else {
            throw URLError(.badURL)
        }
        return url
    }

    private func resolveReference(for skill: Skill) throws -> GitHubReference {
        guard let url = skill.url, let reference = GitHubReference(urlString: url) else {
            throw URLError(.badURL)
        }
        return reference
    }
}
