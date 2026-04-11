import Foundation

actor UVCControlAdapter {
    private let mapper = ControlCapabilityMapper()

    func fetchCapabilities(for _: CameraDeviceDescriptor) async throws -> [CameraControlCapability] {
        mapper.buildPlaceholderCapabilities()
    }

    func readCurrentValues(for _: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        Dictionary(uniqueKeysWithValues: mapper.buildPlaceholderCapabilities().compactMap { capability in
            guard let currentValue = capability.currentValue else {
                return nil
            }
            return (capability.key, currentValue)
        })
    }

    func writeValue(_: CameraControlValue, for _: CameraControlKey, device _: CameraDeviceDescriptor) async throws {
        throw CameraControlError.backendFailure("Raw UVC backend is not wired yet.")
    }
}
