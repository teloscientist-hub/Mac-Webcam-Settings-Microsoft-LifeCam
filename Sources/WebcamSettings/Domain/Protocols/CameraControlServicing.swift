import Foundation

protocol CameraControlServicing: Sendable {
    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [CameraControlCapability]
    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue]
    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws
    func refreshCurrentState(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue]
}
