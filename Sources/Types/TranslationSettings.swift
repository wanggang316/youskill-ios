import Foundation

enum TargetLanguage: String, CaseIterable, Codable, Identifiable {
    case chinese
    case english
    case japanese
    case korean

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .chinese:
            "target_language.chinese"
        case .english:
            "target_language.english"
        case .japanese:
            "target_language.japanese"
        case .korean:
            "target_language.korean"
        }
    }

    var promptValue: String {
        switch self {
        case .chinese:
            "Simplified Chinese"
        case .english:
            "English"
        case .japanese:
            "Japanese"
        case .korean:
            "Korean"
        }
    }
}

/// Global default view applied when a translation is first shown. `original` is reader-only.
enum TranslationDisplayMode: String, CaseIterable, Codable, Identifiable {
    case bilingual
    case translation

    static let `default`: TranslationDisplayMode = .bilingual

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .bilingual:
            "translation_view.bilingual"
        case .translation:
            "translation_view.translation"
        }
    }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = TranslationDisplayMode(rawValue: rawValue) ?? .default
    }
}

/// The reader's temporary view. Kept in memory for the open file only.
enum TranslationView: String, CaseIterable, Identifiable {
    case bilingual
    case translation
    case original

    var id: String { rawValue }

    init(_ mode: TranslationDisplayMode) {
        switch mode {
        case .bilingual:
            self = .bilingual
        case .translation:
            self = .translation
        }
    }

    var titleKey: String {
        switch self {
        case .bilingual:
            "translation_view.bilingual"
        case .translation:
            "translation_view.translation"
        case .original:
            "translation_view.original"
        }
    }
}

enum TranslationSettingField: String, CaseIterable {
    case baseURL
    case apiKey
    case model

    var titleKey: String {
        switch self {
        case .baseURL:
            "settings.base_url"
        case .apiKey:
            "settings.api_key"
        case .model:
            "settings.model"
        }
    }
}

struct TranslationSettings: Codable, Equatable {
    var baseURL: String
    var apiKey: String
    var model: String
    var targetLanguage: TargetLanguage
    var displayMode: TranslationDisplayMode = .default

    static let `default` = TranslationSettings(
        baseURL: "https://openrouter.ai/api/v1",
        apiKey: "",
        model: "",
        targetLanguage: .chinese,
        displayMode: .default
    )

    private enum CodingKeys: String, CodingKey {
        case baseURL
        case apiKey
        case model
        case targetLanguage
        case displayMode
    }

    init(
        baseURL: String,
        apiKey: String,
        model: String,
        targetLanguage: TargetLanguage,
        displayMode: TranslationDisplayMode = .default
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.targetLanguage = targetLanguage
        self.displayMode = displayMode
    }

    // Settings saved before display modes existed have no `displayMode`; they migrate to the default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        model = try container.decode(String.self, forKey: .model)
        targetLanguage = try container.decode(TargetLanguage.self, forKey: .targetLanguage)
        displayMode = (try? container.decodeIfPresent(TranslationDisplayMode.self, forKey: .displayMode)) ?? .default
    }

    var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var missingFields: [TranslationSettingField] {
        TranslationSettingField.allCases.filter { field in
            switch field {
            case .baseURL:
                trimmedBaseURL.isEmpty
            case .apiKey:
                trimmedAPIKey.isEmpty
            case .model:
                trimmedModel.isEmpty
            }
        }
    }

    var isComplete: Bool {
        missingFields.isEmpty
    }
}

enum TranslationCheckState: Equatable {
    case idle
    case checking
    case success(String)
    case failure(String)
}
