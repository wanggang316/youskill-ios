import Foundation
import Testing
@testable import YouSkill

@Suite(.serialized)
struct OpenAICompatibleTranslationRepositoryTests {
    @Test
    func validateAndTranslateUseChatCompletionsEndpoint() async throws {
        let session = makeSession()
        let repository = OpenAICompatibleTranslationRepository(httpClient: HTTPClient(session: session))
        let settings = TranslationSettings(
            baseURL: "https://example.com/v1",
            apiKey: "secret",
            model: "gpt-test",
            targetLanguage: .chinese
        )

        var requestCount = 0
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

        #expect(validation == "OK")
        #expect(translated == "OK")
        #expect(requestCount == 2)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
