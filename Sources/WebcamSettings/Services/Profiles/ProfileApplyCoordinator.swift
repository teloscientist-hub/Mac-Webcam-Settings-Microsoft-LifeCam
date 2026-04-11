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
        let capabilities = (try? await controlService.fetchCapabilities(for: device)) ?? []
        let capabilityMap = Dictionary(uniqueKeysWithValues: capabilities.map { ($0.key, $0) })

        for (key, value) in orderedValues {
            guard let capability = capabilityMap[key], capability.isSupported, capability.isWritable else {
                results.append(.init(key: key, status: .skippedUnsupported, message: "Skipped unsupported control"))
                continue
            }

            let result = await writeCoordinator.write(value, key: key, capability: capability, device: device)
            switch result {
            case .success:
                results.append(.init(key: key, status: .applied, message: "Applied"))
            case let .failure(error):
                results.append(.init(key: key, status: .failed, message: error.localizedDescription))
            }
        }

        logger.info("Applied profile \(profile.name) to \(device.name)")
        await debugStore.record(category: "profiles", message: "Applied profile \(profile.name) to \(device.name)")
        return ProfileApplyResult(items: results)
    }
}
