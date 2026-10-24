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
            translationService: container.translationService,
            translationSettings: { [settingsStore = container.settingsStore] in settingsStore.translationSettings }
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
        .accessibilityIdentifier("skill.detail")
        .navigationTitle(viewModel.displayTitle)
        .platformInlineNavigationTitle()
        .toolbar {
            ToolbarItemGroup(placement: PlatformToolbarPlacement.trailing) {
                translationControl

                Button {
                    drawerBinding.wrappedValue = true
                } label: {
                    Label(L10n.string("detail.directory"), systemImage: "sidebar.right")
                }
                .disabled(viewModel.fileTree.isEmpty)
                .accessibilityIdentifier("detail.files")
            }
        }
        .alert(L10n.string("detail.translation_required_title"), isPresented: $viewModel.needsTranslationSettings) {
            Button(L10n.string("detail.go_to_settings")) {
                isShowingSettings = true
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.format(
                "detail.translation_required_message",
                viewModel.missingTranslationFields.map(\.localizedTitle).joined(separator: ", ")
            ))
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(container: container)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var translationControl: some View {
        if viewModel.hasTranslation {
            Menu {
                Picker(L10n.string("detail.translation_view"), selection: Binding(
                    get: { viewModel.translationView },
                    set: { viewModel.selectTranslationView($0) }
                )) {
                    ForEach(TranslationView.allCases) { view in
                        Text(view.localizedTitle).tag(view)
                    }
                }
                .pickerStyle(.inline)

                Button {
                    Task { await viewModel.retranslate() }
                } label: {
                    Label(L10n.string("detail.retranslate"), systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("detail.retranslate")
            } label: {
                if viewModel.isTranslating {
                    ProgressView()
                        .accessibilityLabel(L10n.string("detail.translating"))
                } else {
                    TranslationViewIcon(view: viewModel.translationView)
                }
            }
            .disabled(viewModel.isTranslating)
            .accessibilityLabel(L10n.string("detail.translation_view"))
            .accessibilityValue(viewModel.translationView.localizedTitle)
            .accessibilityIdentifier("detail.translation-menu")
        } else {
            Button {
                Task { await viewModel.translate() }
            } label: {
                if viewModel.isTranslating {
                    ProgressView()
                        .accessibilityLabel(L10n.string("detail.translating"))
                } else {
                    TranslationViewIcon(view: nil)
                }
            }
            .disabled(!viewModel.canTranslate || viewModel.isTranslating)
            .accessibilityLabel(L10n.string("detail.translate"))
            .accessibilityIdentifier("detail.translate")
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
                HStack(spacing: 6) {
                    Text(activePath)
                        .accessibilityIdentifier("detail.active-file")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                    if viewModel.isLoadingFile {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }

            if let message = viewModel.translationErrorMessage {
                translationErrorBanner(message)
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
                        translatedDescription: viewModel.secondaryDescription,
                        markdown: viewModel.displayedContent,
                        bilingualSegments: viewModel.bilingualSegments,
                        baseURL: viewModel.rawFileURL?.deletingLastPathComponent()
                    )
                case .code:
                    CodeContentView(
                        content: viewModel.displayedContent,
                        fileExtension: URL(fileURLWithPath: viewModel.activePath ?? "").pathExtension.lowercased()
                    )
                    .id(viewModel.activePath)
                case .image:
                    imageContent
                case .unsupported:
                    unsupportedContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Translation failures keep the reader visible and offer a retry.
    private func translationErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string("detail.translation_failed"))
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 0)

            Button(L10n.string("common.retry")) {
                Task { await viewModel.retryTranslation() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                viewModel.dismissTranslationError()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("common.close"))
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
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
