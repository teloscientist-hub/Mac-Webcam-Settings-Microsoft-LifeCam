import AVFoundation
import Foundation

actor DeviceDiscoveryService: DeviceDiscoveryServicing {
    private let logger: AppLogger
    private let debugStore: DebugStore

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
    }

    func currentDevices() async -> [CameraDeviceDescriptor] {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        ).devices

        let mapped = devices.map {
            CameraDeviceDescriptor(
                id: $0.uniqueID,
                name: $0.localizedName,
                manufacturer: nil,
                model: nil,
                transportType: .unknown,
                isConnected: true,
                avFoundationUniqueID: $0.uniqueID,
                backendIdentifier: nil
            )
        }

        logger.info("Discovered \(mapped.count) video devices")
        await debugStore.record(category: "discovery", message: "Discovered \(mapped.count) video devices")
        return mapped
    }

    func startMonitoring() async {
        logger.debug("Device monitoring scaffold started")
        await debugStore.record(category: "discovery", message: "Device monitoring scaffold started")
    }
}
