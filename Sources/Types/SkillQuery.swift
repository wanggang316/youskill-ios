import Foundation

enum SkillSortOption: String, CaseIterable, Identifiable {
    case installCount
    case starCount
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .installCount:
            "安装最多"
        case .starCount:
            "Star 最多"
        case .favorites:
            "我的收藏"
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
    var sortOption: SkillSortOption = .starCount
    var page: Int = 1
    var pageSize: Int = 30

    var skip: Int {
        max((page - 1) * pageSize, 0)
    }

    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
