import Foundation

enum FavoriteState: String, Codable, Sendable {
    case favorited
    case removed
}

/// Skill fields saved when the skill is favorited, so the favorite stays readable
/// after the skill leaves the marketplace.
struct FavoriteSnapshot: Codable, Hashable, Sendable {
    var name: String
    var source: String?
    var description: String?
    // Reader fields are local only; the server snapshot has name, source, and description.
    var url: String?
    var path: String?
    var branch: String?
    var installCount: Int?
    var starCount: Int?

    init(
        name: String,
        source: String? = nil,
        description: String? = nil,
        url: String? = nil,
        path: String? = nil,
        branch: String? = nil,
        installCount: Int? = nil,
        starCount: Int? = nil
    ) {
        self.name = name
        self.source = source
        self.description = description
        self.url = url
        self.path = path
        self.branch = branch
        self.installCount = installCount
        self.starCount = starCount
    }

    init(skill: Skill) {
        self.init(
            name: skill.name,
            source: skill.source,
            description: skill.description,
            url: skill.url,
            path: skill.path,
            branch: skill.branch,
            installCount: skill.installCount,
            starCount: skill.starCount
        )
    }

    /// Takes the server fields and keeps the local reader fields of the same skill.
    func merging(_ remote: FavoriteSnapshot) -> FavoriteSnapshot {
        var merged = remote
        merged.url = remote.url ?? url
        merged.path = remote.path ?? path
        merged.branch = remote.branch ?? branch
        merged.installCount = remote.installCount ?? installCount
        merged.starCount = remote.starCount ?? starCount
        return merged
    }
}

/// A favorite record on this device. Removed records are kept as tombstones until synced.
struct LocalFavorite: Codable, Identifiable, Hashable, Sendable {
    let skillID: Int
    var state: FavoriteState
    var updatedAt: Date
    var snapshot: FavoriteSnapshot
    /// True when the record has a change that the server has not confirmed.
    var isPending: Bool

    var id: Int { skillID }
    var isFavorited: Bool { state == .favorited }

    func asSkill() -> Skill {
        Skill(
            id: skillID,
            name: snapshot.name,
            description: snapshot.description,
            url: snapshot.url,
            path: snapshot.path,
            starCount: snapshot.starCount ?? 0,
            heatScore: 0,
            installCount: snapshot.installCount ?? 0,
            source: snapshot.source,
            branch: snapshot.branch,
            skillPathSHA: nil,
            tags: [],
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }
}

/// A favorite record as the server stores it.
struct RemoteFavorite: Equatable, Sendable {
    let skillID: Int
    let state: FavoriteState
    let updatedAt: Date
    let snapshot: FavoriteSnapshot
}
