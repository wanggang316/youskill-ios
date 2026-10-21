import SwiftUI

struct SkillListView: View {
    let container: AppContainer

    @State private var viewModel: SkillListViewModel
    @State private var repositoriesSelected = false
    @State private var searchDraft = ""
    @State private var isShowingResults = false
    @State private var isShowingSettings = false
    @State private var remoteSort: SkillSortOption = .heatScore
    @State private var scrollPosition: Int?

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: SkillListViewModel(
            service: container.skillCatalogService,
            favoritesStore: container.favoritesStore
        ))
    }

    private var resultTitle: String {
        if viewModel.selectedSort == .favorites { return L10n.string("skill.sort.favorites") }
        switch viewModel.scope {
        case .all: return L10n.string("catalog.all")
        case let .category(category): return category.name
        case let .repository(repository): return repository.name
        }
    }

    private var isRepositoryScope: Bool {
        if case .repository = viewModel.scope { return viewModel.selectedSort != .favorites }
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.string("catalog.browse"), selection: $repositoriesSelected) {
                    Text(L10n.string("catalog.categories")).tag(false)
                    Text(L10n.string("catalog.repositories")).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                List {
                    if !repositoriesSelected {
                        Button { open(.all) } label: {
                            Label(L10n.string("catalog.all"), systemImage: "square.grid.2x2")
                        }
                        .accessibilityIdentifier("catalog.all")
                        ForEach(viewModel.categories) { category in
                            Button { open(.category(category)) } label: {
                                catalogRow(name: category.name, icon: category.icon,
                                           count: category.skillCount, fallback: "tag")
                            }
                        }
                    } else {
                        ForEach(viewModel.repositories) { repository in
                            Button { open(.repository(repository)) } label: {
                                catalogRow(name: repository.name, icon: repository.icon,
                                           count: repository.skillCount, fallback: "shippingbox")
                            }
                        }
                    }
                    if viewModel.isNavigationLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let error = repositoriesSelected ? viewModel.repositoriesError : viewModel.categoriesError {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error).font(.footnote).foregroundStyle(.secondary)
                            Button(L10n.string("common.retry")) {
                                Task { await viewModel.refreshNavigation() }
                            }
                        }
                    } else if repositoriesSelected && viewModel.repositories.isEmpty {
                        EmptyStateView(systemImage: "shippingbox", title: L10n.string("catalog.no_repositories"),
                                       message: L10n.string("catalog.retry_message"))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.refreshNavigation() }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .navigationTitle("YouSkill")
            .platformInlineNavigationTitle()
            .toolbar {
                if !isShowingResults {
                    ToolbarItem(placement: PlatformToolbarPlacement.leading) {
                        Button {
                            if viewModel.selectedSort != .favorites { remoteSort = viewModel.selectedSort }
                            viewModel.selectedSort = .favorites
                            viewModel.selectScope(.all)
                            viewModel.applySearch("")
                            searchDraft = ""
                            scrollPosition = nil
                            isShowingResults = true
                        } label: { Image(systemName: "bookmark") }
                        .accessibilityLabel(L10n.string("skill.sort.favorites"))
                    }
                    ToolbarItem(placement: PlatformToolbarPlacement.trailing) {
                        Button { isShowingSettings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel(L10n.string("settings.title"))
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) { SettingsView(container: container) }
            .navigationDestination(isPresented: $isShowingResults) { results }
            .navigationDestination(for: Skill.self) { skill in
                SkillDetailView(skill: skill, container: container)
            }
            .task { await viewModel.loadNavigationIfNeeded() }
        }
    }

    private func open(_ scope: CatalogScope) {
        if viewModel.scope.key != scope.key || viewModel.selectedSort == .favorites {
            scrollPosition = nil
        }
        viewModel.selectScope(scope)
        if viewModel.selectedSort == .favorites { viewModel.selectedSort = remoteSort }
        searchDraft = viewModel.searchText
        isShowingResults = true
    }

    private func catalogRow(name: String, icon: String?, count: Int, fallback: String) -> some View {
        HStack(spacing: 12) {
            CatalogIconView(icon: icon, fallback: fallback)
            Text(name).foregroundStyle(.primary).lineLimit(2)
            Spacer(minLength: 8)
            Text(count.formatted()).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private var results: some View {
        Group {
            if viewModel.isLoading && viewModel.displayedSkills.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage, viewModel.displayedSkills.isEmpty {
                EmptyStateView(systemImage: "wifi.exclamationmark", title: L10n.string("home.load_failed"),
                               message: error, actionTitle: L10n.string("common.retry"),
                               action: { Task { await viewModel.refresh() } })
            } else if viewModel.displayedSkills.isEmpty {
                EmptyStateView(systemImage: "magnifyingglass",
                               title: L10n.string(viewModel.selectedSort == .favorites ? "home.empty.no_favorites_title" : "home.empty.no_results_title"),
                               message: L10n.string(viewModel.selectedSort == .favorites ? "home.empty.no_favorites_message" : "home.empty.no_results_message"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.displayedSkills) { skill in
                            NavigationLink(value: skill) {
                                SkillCard(skill: skill, showsSource: !isRepositoryScope,
                                          isFavorite: viewModel.isFavorite(skill),
                                          favoriteAction: { viewModel.toggleFavorite(for: skill) })
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("skill.card.\(skill.id)")
                            .id(skill.id)
                            .task { await viewModel.loadMoreIfNeeded(currentSkill: skill) }
                        }
                        if viewModel.isLoadingMore {
                            ProgressView().padding(.vertical, 12)
                        } else if let error = viewModel.errorMessage {
                            VStack(spacing: 8) {
                                Text(error).font(.footnote).foregroundStyle(.secondary)
                                Button(L10n.string("common.retry")) {
                                    guard let last = viewModel.displayedSkills.last else { return }
                                    Task { await viewModel.loadMoreIfNeeded(currentSkill: last) }
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(16)
                }
                .accessibilityIdentifier("catalog.results")
                .scrollPosition(id: $scrollPosition)
                .refreshable { await viewModel.refresh() }
            }
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
        .navigationTitle(resultTitle)
        .platformInlineNavigationTitle()
        .searchable(text: $searchDraft, prompt: L10n.format("catalog.search_scope", resultTitle))
        .onChange(of: searchDraft) { _, value in
            if value.trimmingCharacters(in: .whitespacesAndNewlines) != viewModel.searchText {
                scrollPosition = nil
                viewModel.applySearch(value)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text(resultTitle).font(.headline).lineLimit(1)
                        if isRepositoryScope, case let .repository(repository) = viewModel.scope,
                           let stars = repository.starCount {
                            Label(stars.formatted(), systemImage: "star")
                                .font(.caption).foregroundStyle(.secondary).fixedSize()
                        }
                    }
                    Text(L10n.format("catalog.count", viewModel.selectedSort == .favorites ? viewModel.displayedSkills.count : viewModel.totalCount))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if viewModel.selectedSort != .favorites {
                ToolbarItem(placement: PlatformToolbarPlacement.trailing) {
                    Menu {
                        Picker(L10n.string("catalog.sort"), selection: $viewModel.selectedSort) {
                            Text(SkillSortOption.heatScore.localizedTitle).tag(SkillSortOption.heatScore)
                            Text(SkillSortOption.starCount.localizedTitle).tag(SkillSortOption.starCount)
                        }
                    } label: { Image(systemName: "arrow.up.arrow.down") }
                    .accessibilityLabel(L10n.string("catalog.sort"))
                }
            }
        }
        .onChange(of: viewModel.selectedSort) { _, sort in
            scrollPosition = nil
            if sort != .favorites { remoteSort = sort }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .task(id: viewModel.reloadKey) {
            await viewModel.reloadIfNeeded(for: viewModel.reloadKey)
        }
    }
}
