import Foundation

protocol TranslationRepositoryProtocol: Sendable {
    func validate(settings: TranslationSettings) async throws -> String
    func translate(markdown: String, settings: TranslationSettings) async throws -> String
}

enum TranslationRepositoryError: LocalizedError, Equatable {
    case incompleteSettings
    case modelNotFound(String)

    var errorDescription: String? {
        switch self {
        case .incompleteSettings:
            L10n.string("translation.error.incomplete_settings")
        case let .modelNotFound(model):
            L10n.format("translation.error.model_not_found", model)
        }
    }
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

private struct ModelListResponse: Decodable {
    struct ModelSummary: Decodable {
        let id: String
    }

    let data: [ModelSummary]
}

struct ChatCompletionTranslationRepository: TranslationRepositoryProtocol, Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func validate(settings: TranslationSettings) async throws -> String {
        do {
            let modelListRequest = try makeRequest(
                settings: settings,
                endpoint: .models,
                timeoutInterval: 15
            )
            let models = try await send(modelListRequest, as: ModelListResponse.self)
            let matchesSelectedModel = models.data.contains {
                $0.id.compare(settings.trimmedModel, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }

            guard matchesSelectedModel else {
                throw TranslationRepositoryError.modelNotFound(settings.trimmedModel)
            }

            return L10n.string("translation.validation.success.models")
        } catch let error as TranslationRepositoryError {
            throw error
        } catch let error as HTTPClientError {
            switch error {
            case let .badStatusCode(code, _) where [404, 405, 501].contains(code):
                break
            default:
                throw error
            }
        } catch is DecodingError {
            // Some providers do not expose a standard /models response.
        }

        let request = try makeRequest(
            settings: settings,
            endpoint: .chatCompletions,
            timeoutInterval: 20,
            messages: [
                .init(role: "system", content: "You verify API connectivity. Reply with OK."),
                .init(role: "user", content: "Reply with the single word OK.")
            ],
            maxTokens: 8
        )

        let response = try await send(request, as: ChatCompletionResponse.self)
        guard let content = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw HTTPClientError.emptyResponse
        }
        return L10n.string("translation.validation.success.response")
    }

    func translate(markdown: String, settings: TranslationSettings) async throws -> String {
        let language = settings.targetLanguage.promptValue
        let request = try makeRequest(
            settings: settings,
            endpoint: .chatCompletions,
            timeoutInterval: 90,
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

        let response = try await send(request, as: ChatCompletionResponse.self)
        guard let translated = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !translated.isEmpty else {
            throw HTTPClientError.emptyResponse
        }
        return translated
    }

    private func makeRequest(
        settings: TranslationSettings,
        endpoint: Endpoint,
        timeoutInterval: TimeInterval,
        messages: [ChatCompletionRequest.Message]? = nil,
        maxTokens: Int? = nil
    ) throws -> URLRequest {
        let url = try makeEndpoint(settings: settings, endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(settings.trimmedAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutInterval

        if url.host?.contains("openrouter.ai") == true {
            request.setValue(AppConfiguration.githubURL.absoluteString, forHTTPHeaderField: "HTTP-Referer")
            request.setValue("YouSkill iOS", forHTTPHeaderField: "X-Title")
        }

        if endpoint == .chatCompletions {
            let body = ChatCompletionRequest(
                model: settings.trimmedModel,
                messages: messages ?? [],
                temperature: 0,
                maxTokens: maxTokens ?? 8
            )
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    private func makeEndpoint(settings: TranslationSettings, endpoint: Endpoint) throws -> URL {
        let trimmedBaseURL = settings.trimmedBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let baseURL = URL(string: trimmedBaseURL) else {
            throw URLError(.badURL)
        }

        let normalizedPath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let rootPath: String
        if normalizedPath.hasSuffix("chat/completions") {
            rootPath = String(normalizedPath.dropLast("chat/completions".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else if normalizedPath.hasSuffix("models") {
            rootPath = String(normalizedPath.dropLast("models".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            rootPath = normalizedPath
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let joinedPath = [rootPath, endpoint.path]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components?.path = "/" + joinedPath
        components?.query = nil
        components?.fragment = nil

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        return url
    }

    private func send<Response: Decodable>(_ request: URLRequest, as responseType: Response.Type) async throws -> Response {
        let data = try await httpClient.send(request)
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private enum Endpoint {
    case chatCompletions
    case models

    var path: String {
        switch self {
        case .chatCompletions:
            "chat/completions"
        case .models:
            "models"
        }
    }

    var httpMethod: String {
        switch self {
        case .chatCompletions:
            "POST"
        case .models:
            "GET"
        }
    }
}
