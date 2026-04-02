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
}

struct FavoriteSkill: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let source: String?
    let url: String?
    let path: String?
    let branch: String?
    let installCount: Int
    let starCount: Int
    let addedAt: Date

    init(skill: Skill, addedAt: Date = .now) {
        id = skill.id
        name = skill.name
        source = skill.source
        url = skill.url
        path = skill.path
        branch = skill.branch
        installCount = skill.installCount
        starCount = skill.starCount
        self.addedAt = addedAt
    }

    var displayTitle: String {
        if let owner = source?.split(separator: "/").first {
            return "\(name)(@\(owner))"
        }
        return name
    }

    func asSkill() -> Skill {
        Skill(
            id: id,
            name: name,
            description: nil,
            url: url,
            path: path,
            starCount: starCount,
            heatScore: 0,
            installCount: installCount,
            source: source,
            branch: branch,
            skillPathSHA: nil,
            tags: [],
            createdAt: addedAt,
            updatedAt: addedAt
        )
    }
}
