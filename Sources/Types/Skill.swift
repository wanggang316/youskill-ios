import Foundation

struct SkillsPage: Codable, Equatable {
    let skills: [Skill]
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case skills
        case total
        case page
        case pageSize = "page_size"
    }
}

struct Skill: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let url: String?
    let path: String?
    let starCount: Int
    let heatScore: Int
    let installCount: Int
    let source: String?
    let branch: String?
    let skillPathSHA: String?
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case url
        case path
        case starCount = "star_count"
        case heatScore = "heat_score"
        case installCount = "install_count"
        case source
        case branch
        case skillPathSHA = "skill_path_sha"
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displaySubtitle: String {
        if let handle = creatorHandle {
            return "\(name)(@\(handle))"
        }
        return name
    }

    var creatorHandle: String? {
        if let source, let owner = source.split(separator: "/").first, !owner.isEmpty {
            return String(owner)
        }

        guard let url, let parsed = GitHubReference(urlString: url) else {
            return nil
        }
        return parsed.owner
    }

    var resolvedBranch: String {
        let trimmed = branch?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "main" : trimmed
    }

    var resolvedPath: String {
        (path ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func browserURL(for relativePath: String) -> URL? {
        guard let url, let reference = GitHubReference(urlString: url) else {
            return nil
        }

        let relative = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let combinedPath = [resolvedPath, relative]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        let encodedPath = combinedPath
            .split(separator: "/")
            .map { component in
                String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                    ?? String(component)
            }
            .joined(separator: "/")

        guard !encodedPath.isEmpty else {
            return URL(string: "https://github.com/\(reference.owner)/\(reference.repository)")
        }

        return URL(
            string: "https://github.com/\(reference.owner)/\(reference.repository)/blob/\(resolvedBranch)/\(encodedPath)"
        )
    }
}
