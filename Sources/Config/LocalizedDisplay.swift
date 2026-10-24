import Foundation

extension SkillSortOption {
    var localizedTitle: String {
        L10n.string(titleKey)
    }

    var localizedDescription: String {
        switch self {
        case .heatScore:
            L10n.string("skill.sort.popular")
        case .installCount:
            L10n.string("filter.install_count.description")
        case .starCount:
            L10n.string("filter.star_count.description")
        case .favorites:
            L10n.string("filter.favorites.description")
        }
    }
}

extension TargetLanguage {
    var localizedTitle: String {
        L10n.string(titleKey)
    }
}

extension TranslationDisplayMode {
    var localizedTitle: String {
        L10n.string(titleKey)
    }
}

extension TranslationView {
    var localizedTitle: String {
        L10n.string(titleKey)
    }
}

extension TranslationSettingField {
    var localizedTitle: String {
        L10n.string(titleKey)
    }
}

extension AppLanguage {
    var localizedTitle: String {
        L10n.string(titleKey)
    }
}
