import SwiftUI

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
            ZStack(alignment: .bottom) {
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
                            action: { Task { await viewModel.refresh() } }
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
                            await viewModel.refresh()
                        }
                    }
                }

                if isShowingSortDialog {
                    filterOverlay
                }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.86), value: isShowingSortDialog)
            .navigationTitle("YouSkill")
            .platformInlineNavigationTitle()
            .searchable(text: $searchDraft, prompt: "Search skills")
            .onSubmit(of: .search) {
                viewModel.applySearch(searchDraft)
            }
            .toolbar {
                ToolbarItem(placement: PlatformToolbarPlacement.leading) {
                    Button {
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

    private var filterOverlay: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            isShowingSortDialog = false
                        }
                    }

                SkillFilterSheet(selectedSort: $viewModel.selectedSort) {
                    withAnimation {
                        isShowingSortDialog = false
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }
}
