import SwiftUI

struct SettingsView: View {
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsFormView(container: container)
                .navigationTitle("设置")
                .platformInlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: PlatformToolbarPlacement.trailing) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct SettingsFormView: View {
    let container: AppContainer
    @Bindable var settingsStore: AppSettingsStore

    init(container: AppContainer) {
        self.container = container
        settingsStore = container.settingsStore
    }

    var body: some View {
        Form {
            Section("模型设置") {
                NavigationLink("翻译模型") {
                    ModelSettingsView(
                        settingsStore: container.settingsStore,
                        translationService: container.translationService
                    )
                }

                Picker("目标语言", selection: Binding(
                    get: { settingsStore.translationSettings.targetLanguage },
                    set: { settingsStore.updateTargetLanguage($0) }
                )) {
                    ForEach(TargetLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
            }

            Section("关于") {
                Link(destination: AppConfiguration.githubURL) {
                    Label("GitHub", systemImage: "link")
                }

                LabeledContent("版本", value: AppConfiguration.versionDescription)
            }
        }
    }
}

private struct ModelSettingsView: View {
    let translationService: TranslationService

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TranslationSettings
    @State private var checkState: TranslationCheckState = .idle
    private let settingsStore: AppSettingsStore

    init(settingsStore: AppSettingsStore, translationService: TranslationService) {
        self.settingsStore = settingsStore
        self.translationService = translationService
        _draft = State(initialValue: settingsStore.translationSettings)
    }

    var body: some View {
        Form {
            Section("OpenAI-compatible") {
                TextField("BASE_URL", text: $draft.baseURL)
                    .platformNonAutocorrectingTextInput()
                    .platformURLKeyboard()

                SecureField("API_KEY", text: $draft.apiKey)
                    .platformNonAutocorrectingTextInput()

                TextField("Model", text: $draft.model)
                    .platformNonAutocorrectingTextInput()
            }

            Section {
                Button {
                    Task { await checkConnection() }
                } label: {
                    HStack {
                        if checkState == .checking {
                            ProgressView()
                        }
                        Text("检测")
                    }
                }
                .disabled(checkState == .checking)

                switch checkState {
                case .idle:
                    EmptyView()
                case .checking:
                    Label("正在检测配置…", systemImage: "hourglass")
                        .foregroundStyle(AppTheme.secondaryText)
                case let .success(message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case let .failure(message):
                    Label(message, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("翻译模型")
        .platformInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: PlatformToolbarPlacement.trailing) {
                Button("保存") {
                    settingsStore.update(draft)
                    dismiss()
                }
            }
        }
    }

    @MainActor
    private func checkConnection() async {
        checkState = .checking

        do {
            let result = try await translationService.validate(settings: draft)
            checkState = .success("检测成功：\(result)")
        } catch {
            checkState = .failure(error.localizedDescription)
        }
    }
}
