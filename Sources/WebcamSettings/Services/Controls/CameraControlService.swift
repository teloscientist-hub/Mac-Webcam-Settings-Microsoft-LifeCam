import Foundation

actor CameraControlService: CameraControlServicing {
    private let logger: AppLogger
    private let debugStore: DebugStore
    private let adapter = UVCControlAdapter()

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
    }

    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [CameraControlCapability] {
        let capabilities = try await adapter.fetchCapabilities(for: device)
        logger.info("Fetched \(capabilities.count) capabilities for \(device.name)")
        await debugStore.record(category: "controls", message: "Fetched \(capabilities.count) capabilities for \(device.name)")
        return capabilities
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        let values = try await adapter.readCurrentValues(for: device)
        await debugStore.record(category: "controls", message: "Read \(values.count) current values for \(device.name)")
        return values
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        try await adapter.writeValue(value, for: key, device: device)
        logger.debug("Queued write for \(key.rawValue)")
        await debugStore.record(category: "controls", message: "Queued write for \(key.rawValue)")
    }

    func refreshCurrentState(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        try await readCurrentValues(for: device)
    }
}
