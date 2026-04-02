import Foundation
import Testing
@testable import YouSkill

@MainActor
@Suite(.serialized)
struct FavoritesStoreTests {
    @Test
    func togglePersistsFavorites() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = FavoritesStore(userDefaults: defaults)

        let skill = Skill(
            id: 9,
            name: "translate",
            description: nil,
            url: nil,
            path: nil,
            starCount: 30,
            heatScore: 0,
            installCount: 40,
            source: "demo/repo",
            branch: "main",
            skillPathSHA: nil,
            tags: [],
            createdAt: .now,
            updatedAt: .now
        )

        store.toggle(skill)
        #expect(store.contains(skill))

        let reloaded = FavoritesStore(userDefaults: defaults)
        #expect(reloaded.contains(skill))
        #expect(reloaded.favorites.first?.id == 9)
    }
}
