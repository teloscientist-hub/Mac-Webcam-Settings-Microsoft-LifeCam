import Foundation

protocol DeviceDiscoveryServicing: Sendable {
    func currentDevices() async -> [CameraDeviceDescriptor]
    func deviceUpdates() async -> AsyncStream<[CameraDeviceDescriptor]>
    func startMonitoring() async
}
