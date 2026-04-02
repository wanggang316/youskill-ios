import Foundation
import Testing
@testable import YouSkill

@MainActor
@Suite(.serialized)
struct SkillListViewModelTests {
    @Test
    func loadIfNeededFetchesOnlyOnceForSameQuery() async {
        let repository = FakeSkillCatalogRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()
        await viewModel.reloadIfNeeded(for: viewModel.reloadKey)

        #expect(await repository.fetchCount == 1)
    }

    @Test
    func reloadIfNeededFetchesWhenQueryChanges() async {
        let repository = FakeSkillCatalogRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadIfNeeded()
        viewModel.searchText = "agent"

        await viewModel.reloadIfNeeded(for: viewModel.reloadKey)

        #expect(await repository.fetchCount == 2)
    }

    @Test
    func refreshAlwaysFetchesCurrentQuery() async {
        let repository = FakeSkillCatalogRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadIfNeeded()
        await viewModel.refresh()

        #expect(await repository.fetchCount == 2)
    }

    private func makeViewModel(repository: some SkillCatalogRepositoryProtocol) -> SkillListViewModel {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let favoritesStore = FavoritesStore(userDefaults: defaults)
        let service = SkillCatalogService(repository: repository)
        return SkillListViewModel(service: service, favoritesStore: favoritesStore)
    }
}

private actor FakeSkillCatalogRepository: SkillCatalogRepositoryProtocol {
    private(set) var fetchCount = 0

    func fetchSkills(query: SkillQuery) async throws -> SkillsPage {
        fetchCount += 1

        return SkillsPage(
            skills: [],
            total: 0,
            page: query.page,
            pageSize: query.pageSize
        )
    }
}
