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

    func deviceUpdates() async -> AsyncStream<[CameraDeviceDescriptor]> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.removeContinuation(id)
                }
            }

            Task {
                let devices = await self.currentDevices()
                continuation.yield(devices)
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
}
