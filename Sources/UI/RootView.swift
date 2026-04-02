import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        SkillListView(container: container)
            .tint(AppTheme.accent)
    }
}
