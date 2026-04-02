import Foundation

enum SkillSortOption: String, CaseIterable, Identifiable {
    case installCount
    case starCount
    case favorites

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .installCount:
            "skill.sort.install_count"
        case .starCount:
            "skill.sort.star_count"
        case .favorites:
            "skill.sort.favorites"
        }
    }

    var apiValue: String? {
        switch self {
        case .installCount:
            "install_count"
        case .starCount:
            "star_count"
        case .favorites:
            nil
        }
    }
}

struct SkillQuery: Equatable {
    var searchText: String = ""
    var sortOption: SkillSortOption = .installCount
    var page: Int = 1
    var pageSize: Int = 30

    var skip: Int {
        max((page - 1) * pageSize, 0)
    }

    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
