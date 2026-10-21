import Foundation

struct CatalogIconRepository: Sendable {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchIcon(_ name: String) async throws -> Data {
        guard name.range(of: #"^[a-z0-9]+(?:-[a-z0-9]+)*:[a-z0-9]+(?:-[a-z0-9]+)*$"#,
                         options: .regularExpression) != nil,
              let url = URL(string: "https://api.iconify.design/\(name.replacingOccurrences(of: ":", with: "/")).svg") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("image/svg+xml", forHTTPHeaderField: "Accept")
        let data = try await httpClient.send(request)
        guard data.count <= 256_000 else { throw URLError(.dataLengthExceedsMaximum) }
        return data
    }
}
