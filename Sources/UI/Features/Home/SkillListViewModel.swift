import Foundation
import Observation

@MainActor
@Observable
final class SkillListViewModel {
    private let service: SkillCatalogService
    private let favoritesStore: FavoritesStore

    private(set) var searchText = ""
    var selectedSort: SkillSortOption = .installCount
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
        "\(selectedSort.rawValue)|\(searchText)"
    }

    var displayedSkills: [Skill] {
        _ = favoritesRevision
        if selectedSort == .favorites {
            return favoritesStore.filteredFavorites(searchText: searchText)
        }
        return skills
    }

    var canLoadMore: Bool {
        selectedSort != .favorites && skills.count < totalCount
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
        searchText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reload() async {
        if selectedSort == .favorites {
            errorMessage = nil
            skills = []
            totalCount = favoritesStore.filteredFavorites(searchText: searchText).count
            currentPage = 1
            favoritesRevision = UUID()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let page = try await service.fetchSkills(
                query: SkillQuery(searchText: searchText, sortOption: selectedSort, page: 1, pageSize: 30)
            )
            skills = page.skills
            totalCount = page.total
            currentPage = 1
        } catch {
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

        do {
            let nextPage = currentPage + 1
            let page = try await service.fetchSkills(
                query: SkillQuery(searchText: searchText, sortOption: selectedSort, page: nextPage, pageSize: 30)
            )
            skills.append(contentsOf: page.skills)
            totalCount = page.total
            currentPage = nextPage
        } catch {
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
