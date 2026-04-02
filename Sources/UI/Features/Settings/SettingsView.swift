import SwiftUI

struct SettingsView: View {
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsFormView(container: container)
                .navigationTitle(L10n.string("settings.title"))
                .platformInlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: PlatformToolbarPlacement.trailing) {
                        Button(L10n.string("common.done")) {
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
            Section(L10n.string("settings.section.general")) {
                Picker(L10n.string("settings.app_language"), selection: Binding(
                    get: { settingsStore.appLanguage },
                    set: { settingsStore.updateAppLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.localizedTitle).tag(language)
                    }
                }
            }

            Section(L10n.string("settings.section.model")) {
                NavigationLink(L10n.string("settings.translation_model")) {
                    ModelSettingsView(
                        settingsStore: container.settingsStore,
                        translationService: container.translationService
                    )
                }

                Picker(L10n.string("settings.target_language"), selection: Binding(
                    get: { settingsStore.translationSettings.targetLanguage },
                    set: { settingsStore.updateTargetLanguage($0) }
                )) {
                    ForEach(TargetLanguage.allCases) { language in
                        Text(language.localizedTitle).tag(language)
                    }
                }
            }

            Section(L10n.string("settings.section.about")) {
                Link(destination: AppConfiguration.githubURL) {
                    Label(L10n.string("settings.github"), systemImage: "link")
                }

                LabeledContent(L10n.string("settings.version"), value: AppConfiguration.versionDescription)
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
            Section(L10n.string("settings.openai_compatible")) {
                TextField(L10n.string("settings.base_url"), text: $draft.baseURL)
                    .platformNonAutocorrectingTextInput()
                    .platformURLKeyboard()

                SecureField(L10n.string("settings.api_key"), text: $draft.apiKey)
                    .platformNonAutocorrectingTextInput()

                TextField(L10n.string("settings.model"), text: $draft.model)
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
                        Text(L10n.string("settings.check"))
                    }
                }
                .disabled(checkState == .checking)

                switch checkState {
                case .idle:
                    EmptyView()
                case .checking:
                    Label(L10n.string("settings.checking"), systemImage: "hourglass")
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
        .navigationTitle(L10n.string("settings.model_settings.title"))
        .platformInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: PlatformToolbarPlacement.trailing) {
                Button(L10n.string("common.save")) {
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
            checkState = .success(result)
        } catch {
            checkState = .failure(TranslationValidationErrorFormatter.message(for: error))
        }
    }
}
