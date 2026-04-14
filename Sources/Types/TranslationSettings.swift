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

struct TranslationSettings: Codable, Equatable {
    var baseURL: String
    var apiKey: String
    var model: String
    var targetLanguage: TargetLanguage

    static let `default` = TranslationSettings(
        baseURL: "https://openrouter.ai/api/v1",
        apiKey: "",
        model: "",
        targetLanguage: .chinese
    )

    var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isComplete: Bool {
        !trimmedBaseURL.isEmpty && !trimmedAPIKey.isEmpty && !trimmedModel.isEmpty
    }
}

enum TranslationCheckState: Equatable {
    case idle
    case checking
    case success(String)
    case failure(String)
}
