@preconcurrency import AVFoundation
import Foundation

@MainActor
final class CameraPreviewService: CameraPreviewServicing {
    private let logger: AppLogger
    private let debugStore: DebugStore
    private let backend = AVFoundationPreviewBackend()
    private var session: AVCaptureSession?
    private var activeDeviceID: String?

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
    }

    func startPreview(for device: CameraDeviceDescriptor) async throws -> AVCaptureSession {
        if let session, activeDeviceID == device.id {
            return session
        }

        if session != nil {
            await stopPreview()
        }

        let session = try await backend.startPreview(for: device)
        self.session = session
        self.activeDeviceID = device.id
        logger.info("Preview started for \(device.name)")
        debugStore.record(category: "preview", message: "Preview started for \(device.name)")
        return session
    }

    func stopPreview() async {
        session?.stopRunning()
        session = nil
        activeDeviceID = nil
        logger.debug("Preview stopped")
        debugStore.record(category: "preview", message: "Preview stopped")
    }
}
