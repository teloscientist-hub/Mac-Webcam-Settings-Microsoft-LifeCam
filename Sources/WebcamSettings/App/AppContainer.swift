import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let dependencies: AppDependencies
    let appViewModel: AppViewModel

    init(factory: AppFactory = AppFactory()) {
        self.dependencies = factory.makeDependencies()
        self.appViewModel = AppViewModel(dependencies: dependencies)
    }
}
