import Foundation

enum HTTPClientError: LocalizedError, Equatable {
    case invalidResponse
    case badStatusCode(Int, String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid server response."
        case let .badStatusCode(code, message):
            message.isEmpty ? "Request failed with status \(code)." : message
        case .emptyResponse:
            "The server returned an empty response."
        }
    }
}

struct HTTPClient: Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let message = extractErrorMessage(from: data)
            throw HTTPClientError.badStatusCode(httpResponse.statusCode, message)
        }
        return data
    }

    private func extractErrorMessage(from data: Data) -> String {
        if let parsed = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            if let nested = parsed.error?.message, !nested.isEmpty {
                return nested
            }
            if let message = parsed.message, !message.isEmpty {
                return message
            }
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

private struct ErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String?
    }

    let error: APIError?
    let message: String?
}
