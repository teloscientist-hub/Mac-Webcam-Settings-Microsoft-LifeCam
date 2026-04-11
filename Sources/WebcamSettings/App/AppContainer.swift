import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let dependencies: AppDependencies
    let appViewModel: AppViewModel

    init() {
        let logger = AppLogger(subsystem: "WebcamSettings", category: "app")
        let debugStore = DebugStore()
        let preferencesService = PreferencesService(logger: logger, debugStore: debugStore)
        let deviceDiscoveryService = DeviceDiscoveryService(logger: logger, debugStore: debugStore)
        let previewService = CameraPreviewService(logger: logger, debugStore: debugStore)
        let cameraControlService = CameraControlService(logger: logger, debugStore: debugStore)
        let profileStore = JSONProfileStore(logger: logger, debugStore: debugStore)
        let profileService = ProfileService(store: profileStore, logger: logger, debugStore: debugStore)
        let writeCoordinator = ControlWriteCoordinator(controlService: cameraControlService, logger: logger, debugStore: debugStore)
        let profileApplyCoordinator = ProfileApplyCoordinator(
            controlService: cameraControlService,
            writeCoordinator: writeCoordinator,
            logger: logger,
            debugStore: debugStore
        )
        let lifecycleCoordinator = LifecycleCoordinator(logger: logger, debugStore: debugStore)

        self.dependencies = AppDependencies(
            logger: logger,
            debugStore: debugStore,
            deviceDiscoveryService: deviceDiscoveryService,
            previewService: previewService,
            cameraControlService: cameraControlService,
            profileService: profileService,
            profileApplyingService: profileApplyCoordinator,
            preferencesService: preferencesService,
            lifecycleCoordinator: lifecycleCoordinator
        )
        self.appViewModel = AppViewModel(dependencies: dependencies)
    }
}
