import SwiftUI

struct SkillListView: View {
    let container: AppContainer

    @State private var viewModel: SkillListViewModel
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
                        title: "加载失败",
                        message: errorMessage,
                        actionTitle: "重试",
                        action: { Task { await viewModel.reload() } }
                    )
                } else if viewModel.displayedSkills.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: viewModel.selectedSort == .favorites ? "还没有收藏" : "没有匹配结果",
                        message: viewModel.selectedSort == .favorites ? "把感兴趣的 Skill 加入收藏后，会在这里集中展示。" : "试试更短的关键词或切换排序。"
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
                        await viewModel.reload()
                    }
                }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .navigationTitle("YouSkill")
            .platformInlineNavigationTitle()
            .searchable(text: $viewModel.searchText, prompt: "Search skills")
            .toolbar {
                ToolbarItem(placement: PlatformToolbarPlacement.leading) {
                    Button {
                        isShowingSortDialog = true
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
            .task(id: viewModel.reloadKey) {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await viewModel.reload()
            }
        }
    }
}
