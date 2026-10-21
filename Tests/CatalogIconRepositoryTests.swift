import Foundation
import Testing
@testable import YouSkill

@Suite(.serialized)
struct CatalogIconRepositoryTests {
    @Test
    func fetchesOnlyCanonicalIconNames() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let repository = CatalogIconRepository(httpClient: HTTPClient(session: URLSession(configuration: configuration)))
        MockURLProtocol.register(url: "https://api.iconify.design/lucide/star.svg") { request in
            let url = try #require(request.url)
            #expect(request.value(forHTTPHeaderField: "Accept") == "image/svg+xml")
            let svg = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M0 0h24v24H0z"/></svg>"#
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(svg.utf8))
        }
        let data = try await repository.fetchIcon("lucide:star")
        #expect(!data.isEmpty)
        for invalid in ["", "https://example.com/image.svg", "lucide:../star", "lucide:star?color=red"] {
            do {
                _ = try await repository.fetchIcon(invalid)
                Issue.record("Invalid icon name was accepted")
            } catch let error as URLError {
                #expect(error.code == .badURL)
            }
        }
    }
}
