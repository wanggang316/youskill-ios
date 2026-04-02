import SwiftUI

struct RootView: View {
    let container: AppContainer
    @Bindable var settingsStore: AppSettingsStore

    init(container: AppContainer) {
        self.container = container
        settingsStore = container.settingsStore
    }

    var body: some View {
        SkillListView(container: container)
            .tint(AppTheme.accent)
            .environment(\.locale, settingsStore.appLanguage.locale)
    }
}
