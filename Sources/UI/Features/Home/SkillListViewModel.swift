import Foundation
import Observation

@MainActor
@Observable
final class SkillListViewModel {
    private let service: SkillCatalogService
    private let favoritesStore: FavoritesStore

    private(set) var searchText = ""
    var selectedSort: SkillSortOption = .heatScore {
        didSet {
            if oldValue != selectedSort { invalidateResults() }
        }
    }
    private(set) var scope: CatalogScope = .all
    private(set) var categories: [SkillCategory] = []
    private(set) var repositories: [FeaturedRepository] = []
    private(set) var categoriesError: String?
    private(set) var repositoriesError: String?
    private(set) var isNavigationLoading = false
    private var hasLoadedNavigation = false
    private var requestID = UUID()
    private var reachedEnd = false
    private(set) var skills: [Skill] = []
    private(set) var totalCount = 0
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    private var currentPage = 1
    private var favoritesRevision = UUID()
    private var hasLoadedInitially = false
    private var lastLoadedKey: String?

    init(service: SkillCatalogService, favoritesStore: FavoritesStore) {
        self.service = service
        self.favoritesStore = favoritesStore
    }

    var reloadKey: String {
        "\(scope.key)|\(selectedSort.rawValue)|\(searchText)"
    }

    var displayedSkills: [Skill] {
        _ = favoritesRevision
        if selectedSort == .favorites {
            return favoritesStore.filteredFavorites(searchText: searchText)
        }
        return skills
    }

    var canLoadMore: Bool {
        selectedSort != .favorites && !reachedEnd && skills.count < totalCount
    }

    func loadIfNeeded() async {
        guard !hasLoadedInitially else { return }
        hasLoadedInitially = true
        lastLoadedKey = reloadKey
        await reload()
    }

    func reloadIfNeeded(for key: String) async {
        guard hasLoadedInitially else { return }
        guard lastLoadedKey != key else { return }

        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        guard reloadKey == key else { return }
        guard lastLoadedKey != key else { return }

        lastLoadedKey = key
        await reload()
    }

    func refresh() async {
        hasLoadedInitially = true
        lastLoadedKey = reloadKey
        await reload()
    }

    func applySearch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != searchText else { return }
        searchText = trimmed
        invalidateResults()
    }

    func selectScope(_ newScope: CatalogScope) {
        guard scope.key != newScope.key else { return }
        scope = newScope
        searchText = ""
        invalidateResults()
    }

    private func invalidateResults() {
        requestID = UUID()
        skills = []
        totalCount = 0
        currentPage = 1
        reachedEnd = false
        isLoading = false
        isLoadingMore = false
        errorMessage = nil
    }

    func loadNavigationIfNeeded() async {
        guard !hasLoadedNavigation else { return }
        await refreshNavigation()
    }

    func refreshNavigation() async {
        guard !isNavigationLoading else { return }
        isNavigationLoading = true
        async let categoryLoad: Void = loadCategories()
        async let repositoryLoad: Void = loadRepositories()
        _ = await (categoryLoad, repositoryLoad)
        hasLoadedNavigation = true
        isNavigationLoading = false
    }

    private func loadCategories() async {
        categoriesError = nil
        do { categories = try await service.fetchCategories() }
        catch { categoriesError = error.localizedDescription }
    }

    private func loadRepositories() async {
        repositoriesError = nil
        do { repositories = try await service.fetchHotRepositories() }
        catch { repositoriesError = error.localizedDescription }
    }

    func reload() async {
        requestID = UUID()
        let id = requestID
        let key = reloadKey
        isLoadingMore = false
        reachedEnd = false
        if selectedSort == .favorites {
            errorMessage = nil
            skills = []
            totalCount = favoritesStore.filteredFavorites(searchText: searchText).count
            currentPage = 1
            favoritesRevision = UUID()
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let page = try await service.fetchSkills(
                query: SkillQuery(searchText: searchText, sortOption: selectedSort, page: 1, pageSize: 30, scope: scope)
            )
            guard id == requestID, key == reloadKey else { return }
            skills = page.skills
            reachedEnd = page.skills.isEmpty
            totalCount = page.total
            currentPage = 1
        } catch {
            guard id == requestID, key == reloadKey else { return }
            errorMessage = error.localizedDescription
            skills = []
            totalCount = 0
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentSkill: Skill) async {
        guard !isLoading, !isLoadingMore, canLoadMore else { return }
        guard displayedSkills.last?.id == currentSkill.id else { return }

        isLoadingMore = true
        errorMessage = nil
        let id = requestID
        let key = reloadKey

        do {
            let nextPage = currentPage + 1
            let page = try await service.fetchSkills(
                query: SkillQuery(searchText: searchText, sortOption: selectedSort, page: nextPage, pageSize: 30, scope: scope)
            )
            guard id == requestID, key == reloadKey else { return }
            let existingIDs = Set(skills.map(\.id))
            skills.append(contentsOf: page.skills.filter { !existingIDs.contains($0.id) })
            reachedEnd = page.skills.isEmpty
            totalCount = page.total
            currentPage = nextPage
        } catch {
            guard id == requestID, key == reloadKey else { return }
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    func toggleFavorite(for skill: Skill) {
        favoritesStore.toggle(skill)
        favoritesRevision = UUID()
    }

    func isFavorite(_ skill: Skill) -> Bool {
        favoritesStore.contains(skill)
    }
}
