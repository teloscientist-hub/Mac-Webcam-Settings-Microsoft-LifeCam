import Foundation

actor ProfileApplyCoordinator: ProfileApplying {
    private let controlService: any CameraControlServicing
    private let writeCoordinator: ControlWriteCoordinator
    private let logger: AppLogger
    private let debugStore: DebugStore
    private let planBuilder = ApplyPlanBuilder()

    init(
        controlService: any CameraControlServicing,
        writeCoordinator: ControlWriteCoordinator,
        logger: AppLogger,
        debugStore: DebugStore
    ) {
        self.controlService = controlService
        self.writeCoordinator = writeCoordinator
        self.logger = logger
        self.debugStore = debugStore
    }

    func apply(profile: CameraProfile, to device: CameraDeviceDescriptor) async -> ProfileApplyResult {
        let orderedValues = planBuilder.buildOrderedValues(from: profile.values)
        var results: [ProfileApplyResult.ItemResult] = []

        for (key, value) in orderedValues {
            let result = await writeCoordinator.write(value, key: key, capability: nil, device: device)
            switch result {
            case .success:
                results.append(.init(key: key, status: .applied, message: "Applied"))
            case let .failure(error):
                results.append(.init(key: key, status: .failed, message: error.localizedDescription))
            }
        }

        logger.info("Applied profile \(profile.name) to \(device.name)")
        await debugStore.record(category: "profiles", message: "Applied profile \(profile.name) to \(device.name)")
        _ = controlService
        return ProfileApplyResult(items: results)
    }
}
