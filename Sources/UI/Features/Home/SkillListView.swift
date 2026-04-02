import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SkillListView: View {
    let container: AppContainer

    @State private var viewModel: SkillListViewModel
    @State private var searchDraft = ""
    @State private var isShowingSortDialog = false
    @State private var isShowingSettings = false

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: SkillListViewModel(
            service: container.skillCatalogService,
            favoritesStore: container.favoritesStore
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.displayedSkills.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.displayedSkills.isEmpty {
                    EmptyStateView(
                        systemImage: "wifi.exclamationmark",
                        title: L10n.string("home.load_failed"),
                        message: errorMessage,
                        actionTitle: L10n.string("common.retry"),
                        action: { Task { await viewModel.refresh() } }
                    )
                } else if viewModel.displayedSkills.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: viewModel.selectedSort == .favorites
                            ? L10n.string("home.empty.no_favorites_title")
                            : L10n.string("home.empty.no_results_title"),
                        message: viewModel.selectedSort == .favorites
                            ? L10n.string("home.empty.no_favorites_message")
                            : L10n.string("home.empty.no_results_message")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.displayedSkills) { skill in
                                NavigationLink(value: skill) {
                                    SkillCard(
                                        skill: skill,
                                        isFavorite: viewModel.isFavorite(skill),
                                        favoriteAction: { viewModel.toggleFavorite(for: skill) }
                                    )
                                }
                                .buttonStyle(.plain)
                                .task {
                                    await viewModel.loadMoreIfNeeded(currentSkill: skill)
                                }
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .navigationTitle("YouSkill")
            .platformInlineNavigationTitle()
            .searchable(text: $searchDraft, prompt: L10n.string("home.search_placeholder"))
            .onSubmit(of: .search) {
                viewModel.applySearch(searchDraft)
            }
            .toolbar {
                ToolbarItem(placement: PlatformToolbarPlacement.leading) {
                    Button {
                        dismissSearchKeyboard()
                        withAnimation {
                            isShowingSortDialog = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: PlatformToolbarPlacement.trailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isShowingSortDialog) {
                SkillFilterSheet(selectedSort: $viewModel.selectedSort) {
                    isShowingSortDialog = false
                }
                .presentationDetents([.height(332)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(container: container)
            }
            .navigationDestination(for: Skill.self) { skill in
                SkillDetailView(skill: skill, container: container)
            }
            .task {
                searchDraft = viewModel.searchText
                await viewModel.loadIfNeeded()
            }
            .task(id: viewModel.reloadKey) {
                await viewModel.reloadIfNeeded(for: viewModel.reloadKey)
            }
        }
    }

    private func dismissSearchKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
