@preconcurrency import AVFoundation
import Foundation

actor DeviceDiscoveryService: DeviceDiscoveryServicing {
    private let logger: AppLogger
    private let debugStore: DebugStore
    private var continuations: [UUID: AsyncStream<[CameraDeviceDescriptor]>.Continuation] = [:]
    private var monitorTasks: [Task<Void, Never>] = []

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
    }

    func currentDevices() async -> [CameraDeviceDescriptor] {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices

        let mapped = devices.map {
            let inferredManufacturer = inferredManufacturer(from: $0.localizedName)
            let usbMetadata = USBDeviceRegistry.metadata(
                matching: $0.localizedName,
                manufacturerHint: inferredManufacturer
            )
            return CameraDeviceDescriptor(
                id: $0.uniqueID,
                name: $0.localizedName,
                manufacturer: usbMetadata?.manufacturer ?? inferredManufacturer,
                model: inferredModel(from: $0, usbMetadata: usbMetadata),
                vendorID: usbMetadata?.vendorID,
                productID: usbMetadata?.productID,
                serialNumber: usbMetadata?.serialNumber,
                transportType: transportType(for: $0),
                isConnected: true,
                avFoundationUniqueID: $0.uniqueID,
                backendIdentifier: $0.uniqueID
            )
        }

        logger.info("Discovered \(mapped.count) video devices")
        await debugStore.record(category: "discovery", message: "Discovered \(mapped.count) video devices")
        return mapped
    }

    func deviceUpdates() async -> AsyncStream<[CameraDeviceDescriptor]> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.removeContinuation(id)
                }
            }
        }
    }

    func startMonitoring() async {
        guard monitorTasks.isEmpty else { return }

        monitorTasks = [
            Task { [weak self] in
                guard let self else { return }
                for await _ in NotificationCenter.default.notifications(named: AVCaptureDevice.wasConnectedNotification) {
                    await self.broadcastCurrentDevices(reason: "Camera connected")
                }
            },
            Task { [weak self] in
                guard let self else { return }
                for await _ in NotificationCenter.default.notifications(named: AVCaptureDevice.wasDisconnectedNotification) {
                    await self.broadcastCurrentDevices(reason: "Camera disconnected")
                }
            }
        ]

        logger.debug("Device monitoring scaffold started")
        await debugStore.record(category: "discovery", message: "Device monitoring active")
    }

    private func broadcastCurrentDevices(reason: String) async {
        let devices = await currentDevices()
        logger.info(reason)
        await debugStore.record(category: "discovery", message: reason)
        for continuation in continuations.values {
            continuation.yield(devices)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func transportType(for device: AVCaptureDevice) -> CameraTransportType {
        switch device.deviceType {
        case .continuityCamera:
            .continuity
        case .builtInWideAngleCamera:
            .builtIn
        case .external:
            .usb
        default:
            .unknown
        }
    }

    private func inferredManufacturer(from name: String) -> String? {
        if name.localizedCaseInsensitiveContains("Microsoft") || name.localizedCaseInsensitiveContains("LifeCam") {
            return "Microsoft"
        }
        if name.localizedCaseInsensitiveContains("Logitech") {
            return "Logitech"
        }
        return nil
    }

    private func inferredModel(from device: AVCaptureDevice, usbMetadata: USBDeviceRegistry.Metadata?) -> String? {
        if let productName = usbMetadata?.productName, productName.isEmpty == false {
            return productName
        }
        if device.localizedName.isEmpty == false {
            return device.localizedName
        }
        return nil
    }
}
