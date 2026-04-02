import Foundation
import Testing
@testable import YouSkill

@Suite(.serialized)
struct OpenAICompatibleTranslationRepositoryTests {
    @Test
    func validateUsesModelsEndpointWhenAvailable() async throws {
        try await withAppLanguage(.simplifiedChinese) {
            let session = makeSession()
            let repository = OpenAICompatibleTranslationRepository(httpClient: HTTPClient(session: session))
            let settings = TranslationSettings(
                baseURL: "https://example.com/v1",
                apiKey: "secret",
                model: "gpt-test",
                targetLanguage: .chinese
            )

            var requestCount = 0
            MockURLProtocol.register(url: "https://example.com/v1/models") { request in
                requestCount += 1
                #expect(request.httpMethod == "GET")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
                #expect(request.url?.absoluteString == "https://example.com/v1/models")

                let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
                let payload = """
                {
                  "data": [
                    { "id": "gpt-test" },
                    { "id": "gpt-other" }
                  ]
                }
                """
                return (response, Data(payload.utf8))
            }
            MockURLProtocol.register(url: "https://example.com/v1/chat/completions") { request in
                requestCount += 1
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
                #expect(request.url?.absoluteString == "https://example.com/v1/chat/completions")

                let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
                let payload = """
                {
                  "choices": [
                    {
                      "message": {
                        "content": "OK"
                      }
                    }
                  ]
                }
                """
                return (response, Data(payload.utf8))
            }

            let validation = try await repository.validate(settings: settings)
            let translated = try await repository.translate(markdown: "# Test", settings: settings)

            #expect(validation == "检测成功，模型可用。")
            #expect(translated == "OK")
            #expect(requestCount == 2)
        }
    }

    @Test
    func validateFallsBackToChatCompletionsWhenModelsEndpointIsUnsupported() async throws {
        try await withAppLanguage(.simplifiedChinese) {
            let session = makeSession()
            let repository = OpenAICompatibleTranslationRepository(httpClient: HTTPClient(session: session))
            let settings = TranslationSettings(
                baseURL: "https://example.com/v1",
                apiKey: "secret",
                model: "gpt-test",
                targetLanguage: .chinese
            )

            MockURLProtocol.register(url: "https://example.com/v1/models") { request in
                let response = HTTPURLResponse(url: try #require(request.url), statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (response, Data("not found".utf8))
            }
            MockURLProtocol.register(url: "https://example.com/v1/chat/completions") { request in
                let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
                let payload = """
                {
                  "choices": [
                    {
                      "message": {
                        "content": "OK"
                      }
                    }
                  ]
                }
                """
                return (response, Data(payload.utf8))
            }

            let validation = try await repository.validate(settings: settings)

            #expect(validation == "检测成功，响应正常。")
        }
    }

    @Test
    func validateFailsWhenModelIsNotReturnedByModelsEndpoint() async throws {
        let session = makeSession()
        let repository = OpenAICompatibleTranslationRepository(httpClient: HTTPClient(session: session))
        let settings = TranslationSettings(
            baseURL: "https://example.com/v1",
            apiKey: "secret",
            model: "gpt-missing",
            targetLanguage: .chinese
        )

        MockURLProtocol.register(url: "https://example.com/v1/models") { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!
            let payload = """
            {
              "data": [
                { "id": "gpt-test" }
              ]
            }
            """
            return (response, Data(payload.utf8))
        }

        await #expect(throws: TranslationRepositoryError.modelNotFound("gpt-missing")) {
            try await repository.validate(settings: settings)
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func withAppLanguage(
        _ language: AppLanguage,
        operation: () async throws -> Void
    ) async rethrows {
        let defaults = UserDefaults.standard
        let previousValue = defaults.string(forKey: AppLanguage.storageKey)
        defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: AppLanguage.storageKey)
            } else {
                defaults.removeObject(forKey: AppLanguage.storageKey)
            }
        }
        try await operation()
    }
}
