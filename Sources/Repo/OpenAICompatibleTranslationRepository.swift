import Foundation

protocol TranslationRepositoryProtocol: Sendable {
    func validate(settings: TranslationSettings) async throws -> String
    func translate(markdown: String, settings: TranslationSettings) async throws -> String
}

private struct ChatCompletionRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)

                if let string = try? container.decode(String.self, forKey: .content) {
                    content = string
                    return
                }

                let parts = try container.decode([ContentPart].self, forKey: .content)
                content = parts.map(\.text).joined(separator: "\n")
            }

            private enum CodingKeys: String, CodingKey {
                case content
            }

            private struct ContentPart: Decodable {
                let text: String

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
                }

                private enum CodingKeys: String, CodingKey {
                    case text
                }
            }
        }

        let message: Message
    }

    let choices: [Choice]
}

struct OpenAICompatibleTranslationRepository: TranslationRepositoryProtocol, Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func validate(settings: TranslationSettings) async throws -> String {
        let request = try makeRequest(
            settings: settings,
            messages: [
                .init(role: "system", content: "You verify API connectivity. Reply with OK."),
                .init(role: "user", content: "Reply with the single word OK.")
            ],
            maxTokens: 8
        )

        let response = try await send(request)
        guard let content = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw HTTPClientError.emptyResponse
        }
        return content
    }

    func translate(markdown: String, settings: TranslationSettings) async throws -> String {
        let language = settings.targetLanguage.promptValue
        let request = try makeRequest(
            settings: settings,
            messages: [
                .init(
                    role: "system",
                    content: """
                    You are a professional technical translator.
                    Translate the user provided markdown into \(language).
                    Preserve headings, tables, bullet lists, links, filenames, inline code, fenced code blocks, and technical identifiers.
                    Return markdown only.
                    """
                ),
                .init(role: "user", content: markdown)
            ],
            maxTokens: 4000
        )

        let response = try await send(request)
        guard let translated = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !translated.isEmpty else {
            throw HTTPClientError.emptyResponse
        }
        return translated
    }

    private func makeRequest(
        settings: TranslationSettings,
        messages: [ChatCompletionRequest.Message],
        maxTokens: Int
    ) throws -> URLRequest {
        let trimmedBaseURL = settings.trimmedBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let baseURL = URL(string: trimmedBaseURL) else {
            throw URLError(.badURL)
        }

        let endpoint: URL
        if baseURL.absoluteString.hasSuffix("/chat/completions") {
            endpoint = baseURL
        } else {
            endpoint = baseURL.appending(path: "chat/completions")
        }

        let body = ChatCompletionRequest(
            model: settings.trimmedModel,
            messages: messages,
            temperature: 0,
            maxTokens: maxTokens
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(settings.trimmedAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func send(_ request: URLRequest) async throws -> ChatCompletionResponse {
        let data = try await httpClient.send(request)
        return try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
    }
}
