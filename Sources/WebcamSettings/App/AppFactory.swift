import Foundation

struct AppFactory {
    let logger: AppLogger
    let debugStore: DebugStore

    @MainActor
    init(
        logger: AppLogger = AppLogger(subsystem: "WebcamSettings", category: "app"),
        debugStore: DebugStore? = nil
    ) {
        self.logger = logger
        self.debugStore = debugStore ?? DebugStore()
    }

    @MainActor
    func makeDependencies() -> AppDependencies {
        let preferencesService = PreferencesService(logger: logger, debugStore: debugStore)
        let deviceDiscoveryService = DeviceDiscoveryService(logger: logger, debugStore: debugStore)
        let previewService = CameraPreviewService(logger: logger, debugStore: debugStore)
        #if canImport(IOKit)
        let rawExecutor: any RawUVCControlTransferExecuting = IOKitRawUVCControlTransferExecutor()
        #else
        let rawExecutor: any RawUVCControlTransferExecuting = UnavailableRawUVCControlTransferExecutor()
        #endif
        let rawTransport = LoggingRawUVCTransport(
            wrapped: PolicyRawUVCTransport(
                wrapped: ValidatingRawUVCTransport(
                    wrapped: UnavailableRawUVCTransport(executor: rawExecutor),
                    logger: logger,
                    debugStore: debugStore
                ),
                policy: .default,
                logger: logger,
                debugStore: debugStore
            ),
            logger: logger,
            debugStore: debugStore
        )
        let backend = FallbackUVCCameraBackend(
            preferred: SyntheticRawUVCCameraBackend(transport: rawTransport),
            fallback: InMemoryUVCCameraBackend(),
            logger: logger,
            debugStore: debugStore
        )
        let adapter = UVCControlAdapter(backend: backend)
        let cameraControlService = CameraControlService(logger: logger, debugStore: debugStore, adapter: adapter)
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

        return AppDependencies(
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
    }
}
