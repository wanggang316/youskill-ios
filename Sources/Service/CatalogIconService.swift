import Foundation

actor CatalogIconService {
    static let shared = CatalogIconService()
    private let repository = CatalogIconRepository()
    private var cache: [String: Data] = [:]

    func icon(named name: String) async throws -> Data {
        if let data = cache[name] { return data }
        let data = try await repository.fetchIcon(name)
        if cache.count >= 256 { cache.removeAll(keepingCapacity: true) }
        cache[name] = data
        return data
    }
}
