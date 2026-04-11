import Foundation

actor FallbackUVCCameraBackend: UVCCameraBackend {
    private let preferred: any UVCCameraBackend
    private let fallback: any UVCCameraBackend
    private let logger: AppLogger?
    private let debugStore: DebugStore?

    init(
        preferred: any UVCCameraBackend,
        fallback: any UVCCameraBackend,
        logger: AppLogger? = nil,
        debugStore: DebugStore? = nil
    ) {
        self.preferred = preferred
        self.fallback = fallback
        self.logger = logger
        self.debugStore = debugStore
    }

    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [BackendControlCapability] {
        try await run(primaryOperation: "fetch capabilities", for: device) { backend in
            try await backend.fetchCapabilities(for: device)
        }
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        try await run(primaryOperation: "read values", for: device) { backend in
            try await backend.readCurrentValues(for: device)
        }
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        let _: Void = try await run(primaryOperation: "write \(key.rawValue)", for: device) { backend in
            try await backend.writeValue(value, for: key, device: device)
        }
    }

    private func run<Result: Sendable>(
        primaryOperation: String,
        for device: CameraDeviceDescriptor,
        using operation: @Sendable (any UVCCameraBackend) async throws -> Result
    ) async throws -> Result {
        do {
            return try await operation(preferred)
        } catch {
            await recordFallback(primaryOperation: primaryOperation, device: device, error: error)
            return try await operation(fallback)
        }
    }

    private func recordFallback(primaryOperation: String, device: CameraDeviceDescriptor, error: Error) async {
        let message = "Preferred UVC backend failed to \(primaryOperation) for \(device.name); falling back: \(error.localizedDescription)"
        logger?.debug(message)
        await debugStore?.record(category: "uvc-backend", message: message)
    }
}
