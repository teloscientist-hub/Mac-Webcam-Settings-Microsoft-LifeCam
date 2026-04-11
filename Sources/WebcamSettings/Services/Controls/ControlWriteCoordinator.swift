import Foundation

actor ControlWriteCoordinator {
    private let controlService: any CameraControlServicing
    private let logger: AppLogger
    private let debugStore: DebugStore

    init(controlService: any CameraControlServicing, logger: AppLogger, debugStore: DebugStore) {
        self.controlService = controlService
        self.logger = logger
        self.debugStore = debugStore
    }

    func write(_ value: CameraControlValue, key: CameraControlKey, device: CameraDeviceDescriptor) async -> Result<Void, CameraControlError> {
        do {
            try await controlService.writeValue(value, for: key, device: device)
            logger.info("Wrote control \(key.rawValue)")
            await debugStore.record(category: "write", message: "Wrote control \(key.rawValue)")
            return .success(())
        } catch let error as CameraControlError {
            logger.error("Write failed for \(key.rawValue): \(error.localizedDescription)")
            await debugStore.record(category: "write", message: "Write failed for \(key.rawValue): \(error.localizedDescription)")
            return .failure(error)
        } catch {
            logger.error("Write failed for \(key.rawValue): \(error.localizedDescription)")
            await debugStore.record(category: "write", message: "Write failed for \(key.rawValue): \(error.localizedDescription)")
            return .failure(.backendFailure(error.localizedDescription))
        }
    }
}
