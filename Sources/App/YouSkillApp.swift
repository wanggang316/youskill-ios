import SwiftUI

@main
struct YouSkillApp: App {
    @State private var container = AppContainer.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Launch and every return to the app pull changes from other devices.
            if phase == .active {
                Task { await container.favoriteSyncService.sync() }
            }
        }
    }
}
