import Foundation

actor UVCControlAdapter {
    private let backend: any UVCCameraBackend
    private let mapper = ControlCapabilityMapper()

    init(backend: any UVCCameraBackend = InMemoryUVCCameraBackend()) {
        self.backend = backend
    }

    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [CameraControlCapability] {
        let backendCapabilities = try await backend.fetchCapabilities(for: device)
        return mapper.mapBackendCapabilities(backendCapabilities)
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        try await backend.readCurrentValues(for: device)
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        try await backend.writeValue(value, for: key, device: device)
    }
}
