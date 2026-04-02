import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case system
    case simplifiedChinese
    case english
    case japanese
    case korean

    static let storageKey = "app-language"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        case .english:
            Locale(identifier: "en")
        case .japanese:
            Locale(identifier: "ja")
        case .korean:
            Locale(identifier: "ko")
        }
    }

    var preferredLocalizationIdentifiers: [String] {
        switch self {
        case .system:
            Locale.preferredLanguages
        case .simplifiedChinese:
            ["zh-Hans", "zh"]
        case .english:
            ["en"]
        case .japanese:
            ["ja"]
        case .korean:
            ["ko"]
        }
    }

    var titleKey: String {
        switch self {
        case .system:
            "app_language.system"
        case .simplifiedChinese:
            "app_language.zh_hans"
        case .english:
            "app_language.en"
        case .japanese:
            "app_language.ja"
        case .korean:
            "app_language.ko"
        }
    }

    static func current(userDefaults: UserDefaults = .standard) -> AppLanguage {
        guard let rawValue = userDefaults.string(forKey: storageKey),
              let language = AppLanguage(rawValue: rawValue) else {
            return .system
        }
        return language
    }
}
