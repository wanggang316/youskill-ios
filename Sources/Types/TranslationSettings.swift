import Foundation

enum TargetLanguage: String, CaseIterable, Codable, Identifiable {
    case chinese
    case english
    case japanese
    case korean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese:
            "中文"
        case .english:
            "English"
        case .japanese:
            "日本語"
        case .korean:
            "한국어"
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
        baseURL: "https://api.openai.com/v1",
        apiKey: "",
        model: "gpt-4o-mini",
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
