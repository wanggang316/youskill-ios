import SwiftUI

struct SkillDetailView: View {
    let container: AppContainer

    @State private var viewModel: SkillDetailViewModel
    @State private var isShowingSettings = false

    init(skill: Skill, container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: SkillDetailViewModel(
            skill: skill,
            contentService: container.skillContentService,
            translationService: container.translationService
        ))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if viewModel.isLoading && viewModel.activePath == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.activePath == nil {
                    EmptyStateView(
                        systemImage: "exclamationmark.triangle",
                        title: "读取失败",
                        message: errorMessage,
                        actionTitle: "重试",
                        action: { Task { await viewModel.load() } }
                    )
                } else {
                    contentBody
                }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())

            FileTreeDrawer(
                isPresented: viewModel.isDrawerOpen,
                nodes: viewModel.fileTree,
                activePath: viewModel.activePath,
                onClose: { viewModel.isDrawerOpen = false },
                onSelect: { path in
                    Task { await viewModel.loadFile(at: path) }
                }
            )
        }
        .navigationTitle(viewModel.displayTitle)
        .platformInlineNavigationTitle()
        .toolbar {
            ToolbarItemGroup(placement: PlatformToolbarPlacement.trailing) {
                Button {
                    Task {
                        await viewModel.toggleTranslation(using: container.settingsStore.translationSettings)
                    }
                } label: {
                    if viewModel.isTranslating {
                        ProgressView()
                    } else {
                        Image(systemName: viewModel.isShowingTranslated ? "text.badge.checkmark" : "globe")
                    }
                }
                .disabled(!viewModel.canTranslate || viewModel.isTranslating)

                Button {
                    viewModel.isDrawerOpen = true
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .disabled(viewModel.fileTree.isEmpty)
            }
        }
        .alert("请先配置翻译模型", isPresented: $viewModel.needsTranslationSettings) {
            Button("去设置") {
                isShowingSettings = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("需要填写 BASE_URL、API_KEY 和 Model 后才能翻译。")
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(container: container)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        VStack(spacing: 0) {
            if let activePath = viewModel.activePath {
                HStack {
                    Text(activePath)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty, viewModel.activePath != nil {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "内容加载失败",
                    message: errorMessage,
                    actionTitle: "重试",
                    action: {
                        if let activePath = viewModel.activePath {
                            Task { await viewModel.loadFile(at: activePath) }
                        }
                    }
                )
            } else {
                switch viewModel.fileKind {
                case .markdown:
                    MarkdownContentView(
                        description: viewModel.displayedDescription,
                        markdown: viewModel.displayedContent
                    )
                case .code:
                    CodeContentView(content: viewModel.displayedContent)
                case .image:
                    imageContent
                case .unsupported:
                    unsupportedContent
                }
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let url = viewModel.rawFileURL {
            ScrollView {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .padding(.top, 40)
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                    case .failure:
                        EmptyStateView(
                            systemImage: "photo",
                            title: "图片加载失败",
                            message: "当前图片无法预览。"
                        )
                    @unknown default:
                        EmptyStateView(
                            systemImage: "photo",
                            title: "图片暂不可用",
                            message: "请稍后重试。"
                        )
                    }
                }
            }
        } else {
            unsupportedContent
        }
    }

    private var unsupportedContent: some View {
        EmptyStateView(
            systemImage: "doc",
            title: "暂不支持预览",
            message: "当前文件不是 Markdown、代码或图片文件。"
        )
    }
}
