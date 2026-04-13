import Foundation

struct AppDependencies {
    let logger: AppLogger
    let debugStore: DebugStore
    let deviceDiscoveryService: any DeviceDiscoveryServicing
    let previewService: any CameraPreviewServicing
    let cameraControlService: any CameraControlServicing
    let profileService: any ProfileServicing
    let profileApplyingService: any ProfileApplying
    let preferencesService: any PreferencesServicing
    let launchAtLoginService: any LaunchAtLoginServicing
    let lifecycleCoordinator: LifecycleCoordinator
}
