import SwiftUI

struct SkillDetailView: View {
    let container: AppContainer
    @Environment(\.openURL) private var openURL
    private let drawerAnimation = Animation.interactiveSpring(
        response: 0.32,
        dampingFraction: 0.86,
        blendDuration: 0.12
    )

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
                        title: L10n.string("detail.read_failed"),
                        message: errorMessage,
                        actionTitle: L10n.string("common.retry"),
                        action: { Task { await viewModel.load() } }
                    )
                } else {
                    contentBody
                }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())

            FileTreeDrawer(
                isPresented: drawerBinding,
                nodes: viewModel.fileTree,
                activePath: viewModel.activePath,
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
                    drawerBinding.wrappedValue = true
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .disabled(viewModel.fileTree.isEmpty)
            }
        }
        .alert(L10n.string("detail.translation_required_title"), isPresented: $viewModel.needsTranslationSettings) {
            Button(L10n.string("detail.go_to_settings")) {
                isShowingSettings = true
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("detail.translation_required_message"))
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(container: container)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var drawerBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isDrawerOpen },
            set: { isPresented in
                withAnimation(drawerAnimation) {
                    viewModel.isDrawerOpen = isPresented
                }
            }
        )
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
                    title: L10n.string("detail.content_load_failed"),
                    message: errorMessage,
                    actionTitle: L10n.string("common.retry"),
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
                        markdown: viewModel.displayedContent,
                        baseURL: viewModel.rawFileURL?.deletingLastPathComponent()
                    )
                case .code:
                    CodeContentView(
                        content: viewModel.displayedContent,
                        fileExtension: URL(fileURLWithPath: viewModel.activePath ?? "").pathExtension.lowercased()
                    )
                case .image:
                    imageContent
                case .unsupported:
                    unsupportedContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                            title: L10n.string("detail.image_load_failed"),
                            message: L10n.string("detail.image_load_failed_message")
                        )
                    @unknown default:
                        EmptyStateView(
                            systemImage: "photo",
                            title: L10n.string("detail.image_unavailable"),
                            message: L10n.string("detail.image_unavailable_message")
                        )
                    }
                }
            }
        } else {
            unsupportedContent
        }
    }

    private var unsupportedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.string("detail.unsupported.title"), systemImage: "doc.text.magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(L10n.string("detail.unsupported.message"))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if let activePath = viewModel.activePath {
                    fileInfoRow(title: L10n.string("detail.file_label"), value: activePath)
                }

                fileInfoRow(
                    title: L10n.string("detail.type_label"),
                    value: URL(fileURLWithPath: viewModel.activePath ?? "").pathExtension.uppercased().ifEmpty(L10n.string("common.unknown"))
                )

                if let sourceURL = viewModel.browserFileURL ?? viewModel.rawFileURL {
                    Button {
                        openURL(sourceURL)
                    } label: {
                        Label(L10n.string("detail.open_source"), systemImage: "arrow.up.forward.square")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.divider, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(AppTheme.groupedBackground)
    }

    private func fileInfoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)

            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
