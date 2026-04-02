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
            let message = String(data: data, encoding: .utf8) ?? ""
            throw HTTPClientError.badStatusCode(httpResponse.statusCode, message)
        }
        return data
    }
}
