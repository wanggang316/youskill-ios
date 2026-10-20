import Foundation

struct SkillCategory: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let icon: String?
    let skillCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case skillCount = "skill_count"
    }
}

struct FeaturedRepository: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let icon: String?
    let skillCount: Int
    let starCount: Int?
    let enabled: Bool
    let type: String

    enum CodingKeys: String, CodingKey {
        case id, name, icon, enabled, type
        case skillCount = "skill_count"
        case starCount = "star_count"
    }
}

enum CatalogScope: Hashable, Sendable {
    case all
    case category(SkillCategory)
    case repository(FeaturedRepository)

    var key: String {
        switch self {
        case .all: "all"
        case let .category(category): "category:\(category.id)"
        case let .repository(repository): "repository:\(repository.name)"
        }
    }
}
