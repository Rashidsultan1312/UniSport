import SwiftUI

@main
struct UniSportApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            LaunchScaffold {
                RootAppView(container: container)
            }
        }
    }
}
