@preconcurrency import AVFoundation
import Foundation

@MainActor
final class CameraPreviewService: CameraPreviewServicing {
    private let logger: AppLogger
    private let debugStore: DebugStore
    private let backend = AVFoundationPreviewBackend()
    private var session: AVCaptureSession?

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
    }

    func startPreview(for device: CameraDeviceDescriptor) async throws -> AVCaptureSession {
        let session = try await backend.startPreview(for: device)
        self.session = session
        logger.info("Preview started for \(device.name)")
        debugStore.record(category: "preview", message: "Preview started for \(device.name)")
        return session
    }

    func stopPreview() async {
        session?.stopRunning()
        session = nil
        logger.debug("Preview stopped")
        debugStore.record(category: "preview", message: "Preview stopped")
    }
}
