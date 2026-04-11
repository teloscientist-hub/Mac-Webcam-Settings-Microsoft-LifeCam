import SwiftUI

@main
struct WebcamSettingsApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            MainWindowView(viewModel: container.appViewModel)
        }
        .defaultSize(width: 1080, height: 760)
    }
}
