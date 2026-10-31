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
        viewModel.applySearch("agent")

        await viewModel.reloadIfNeeded(for: viewModel.reloadKey)

        #expect(await repository.fetchCount == 2)
    }

    @Test
    func applySearchTrimsWhitespace() async {
        let repository = FakeSkillCatalogRepository()
        let viewModel = makeViewModel(repository: repository)

        viewModel.applySearch("  agent skill  ")

        #expect(viewModel.searchText == "agent skill")
        #expect(viewModel.reloadKey == "all|\(viewModel.selectedSort.rawValue)|agent skill")
    }

    @Test
    func refreshAlwaysFetchesCurrentQuery() async {
        let repository = FakeSkillCatalogRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadIfNeeded()
        await viewModel.refresh()

        #expect(await repository.fetchCount == 2)
    }

    @Test
    func selectingScopeClearsSearchAndKeepsSort() async {
        let repository = FakeSkillCatalogRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.selectedSort = .starCount
        viewModel.applySearch("review")
        let category = SkillCategory(id: 7, name: "design", icon: nil, skillCount: 2)
        viewModel.selectScope(.category(category))
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.selectedSort == .starCount)
        await viewModel.reload()
        #expect(await repository.queries.last?.scope == .category(category))
    }

    @Test
    func oldScopeResponseCannotReplaceCurrentResults() async {
        let repository = ControlledCatalogRepository()
        let viewModel = makeViewModel(repository: repository)
        let first = Task { await viewModel.reload() }
        await repository.waitForRequest(1)
        let category = SkillCategory(id: 7, name: "design", icon: nil, skillCount: 1)
        viewModel.selectScope(.category(category))
        let second = Task { await viewModel.reload() }
        await repository.waitForRequest(2)
        await repository.complete(2, result: .success(page([sampleSkill(2)])))
        await second.value
        await repository.complete(1, result: .success(page([sampleSkill(1)])))
        await first.value
        #expect(viewModel.skills.map(\.id) == [2])
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func failedPaginationRetriesSamePageAndPreservesResults() async {
        let repository = ControlledCatalogRepository()
        let viewModel = makeViewModel(repository: repository)
        let initial = Task { await viewModel.reload() }
        await repository.waitForRequest(1)
        await repository.complete(1, result: .success(page([sampleSkill(1)], total: 3)))
        await initial.value
        let next = Task { await viewModel.loadMoreIfNeeded(currentSkill: sampleSkill(1)) }
        await repository.waitForRequest(2)
        await repository.complete(2, result: .failure(URLError(.timedOut)))
        await next.value
        #expect(viewModel.skills.map(\.id) == [1])
        let retry = Task { await viewModel.loadMoreIfNeeded(currentSkill: sampleSkill(1)) }
        await repository.waitForRequest(3)
        await repository.complete(3, result: .success(page([sampleSkill(1), sampleSkill(2)], total: 3)))
        await retry.value
        #expect(await repository.queries.map(\.page) == [1, 2, 2])
        #expect(viewModel.skills.map(\.id) == [1, 2])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func repositoryNavigationLoadsWhenCategoriesFail() async {
        let repository = ControlledCatalogRepository()
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadNavigationIfNeeded()
        #expect(viewModel.categoriesError != nil)
        #expect(viewModel.repositories.count == 1)
        #expect(!viewModel.isNavigationLoading)
    }

    @Test
    func returningToResultsKeepsScopeQuerySortAndLoadedSkills() async {
        let repository = FakeSkillCatalogRepository()
        let viewModel = makeViewModel(repository: repository)
        let category = SkillCategory(id: 7, name: "design", icon: nil, skillCount: 1)
        viewModel.selectScope(.category(category))
        viewModel.selectedSort = .starCount
        viewModel.applySearch("layout")
        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()
        await viewModel.reloadIfNeeded(for: viewModel.reloadKey)
        #expect(await repository.fetchCount == 1)
        #expect(viewModel.scope == .category(category))
        #expect(viewModel.searchText == "layout")
        #expect(viewModel.selectedSort == .starCount)
    }

    @Test
    func favoritesDoNotFetchRemoteSkills() async {
        let repository = FakeSkillCatalogRepository()
        let viewModel = makeViewModel(repository: repository)
        let skill = sampleSkill(1)
        viewModel.toggleFavorite(for: skill)
        viewModel.selectedSort = .favorites
        await viewModel.loadIfNeeded()
        #expect(viewModel.displayedSkills.map(\.id) == [1])
        #expect(await repository.fetchCount == 0)
        #expect(!viewModel.canLoadMore)
    }

    @Test
    func favoritesResolveLiveSkillsOnceAndMarkMissingOnesUnavailable() async {
        let repository = FakeSkillCatalogRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.toggleFavorite(for: sampleSkill(1))
        viewModel.toggleFavorite(for: sampleSkill(2))
        var live = sampleSkill(1)
        live = Skill(id: 1, name: "renamed", description: "live", url: "https://github.com/team/tools",
                     path: "skills/one", starCount: 9, heatScore: 0, installCount: 0, source: live.source,
                     branch: "main", skillPathSHA: nil, tags: [], createdAt: .now, updatedAt: .now)
        await repository.setLiveSkill(live)
        viewModel.selectedSort = .favorites

        for skill in viewModel.displayedSkills {
            await viewModel.resolveFavoriteIfNeeded(skill)
            await viewModel.resolveFavoriteIfNeeded(skill)
        }

        #expect(await repository.lookups.sorted() == [1, 2])
        #expect(viewModel.displayedSkills.first { $0.id == 1 }?.name == "renamed")
        let missing = viewModel.displayedSkills.first { $0.id == 2 }
        #expect(missing?.name == "skill-2")
        #expect(missing.map(viewModel.isUnavailable) == true)

        viewModel.toggleFavorite(for: missing!)
        #expect(viewModel.displayedSkills.map(\.id) == [1])
    }

    private func sampleSkill(_ id: Int) -> Skill {
        Skill(id: id, name: "skill-\(id)", description: nil, url: nil, path: nil,
              starCount: 120, heatScore: 10, installCount: 1, source: "team/tools",
              branch: nil, skillPathSHA: nil, tags: [], createdAt: .now, updatedAt: .now)
    }

    private func page(_ skills: [Skill], total: Int? = nil) -> SkillsPage {
        SkillsPage(skills: skills, total: total ?? skills.count, page: 1, pageSize: 30)
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
    private(set) var queries: [SkillQuery] = []
    private(set) var lookups: [Int] = []
    var liveSkills: [Int: Skill] = [:]

    func fetchCategories() async throws -> [SkillCategory] { [] }
    func fetchHotRepositories() async throws -> [FeaturedRepository] { [] }

    func setLiveSkill(_ skill: Skill) { liveSkills[skill.id] = skill }

    func fetchSkill(id: Int) async throws -> Skill? {
        lookups.append(id)
        return liveSkills[id]
    }

    func fetchSkills(query: SkillQuery) async throws -> SkillsPage {
        fetchCount += 1
        queries.append(query)

        return SkillsPage(
            skills: [],
            total: 0,
            page: query.page,
            pageSize: query.pageSize
        )
    }
}

private actor ControlledCatalogRepository: SkillCatalogRepositoryProtocol {
    private(set) var queries: [SkillQuery] = []
    private var pending: [Int: CheckedContinuation<SkillsPage, any Error>] = [:]
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]

    func fetchSkills(query: SkillQuery) async throws -> SkillsPage {
        queries.append(query)
        let index = queries.count
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            waiters.removeValue(forKey: index)?.resume()
        }
    }

    func waitForRequest(_ index: Int) async {
        if pending[index] != nil { return }
        await withCheckedContinuation { waiters[index] = $0 }
    }

    func complete(_ index: Int, result: Result<SkillsPage, any Error>) {
        pending.removeValue(forKey: index)?.resume(with: result)
    }

    func fetchCategories() async throws -> [SkillCategory] { throw URLError(.timedOut) }

    func fetchSkill(id: Int) async throws -> Skill? { nil }

    func fetchHotRepositories() async throws -> [FeaturedRepository] {
        [FeaturedRepository(id: 1, name: "team/tools", icon: nil, skillCount: 2,
                            starCount: 120, enabled: true, type: "hot")]
    }
}
