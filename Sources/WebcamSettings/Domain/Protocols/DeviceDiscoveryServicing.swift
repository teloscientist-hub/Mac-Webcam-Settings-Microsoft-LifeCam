import Foundation

protocol DeviceDiscoveryServicing: Sendable {
    func currentDevices() async -> [CameraDeviceDescriptor]
    func startMonitoring() async
}
