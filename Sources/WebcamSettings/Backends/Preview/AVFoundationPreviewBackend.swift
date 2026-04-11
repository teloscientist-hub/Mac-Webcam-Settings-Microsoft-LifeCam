@preconcurrency import AVFoundation
import Foundation

@MainActor
final class AVFoundationPreviewBackend {
    func startPreview(for device: CameraDeviceDescriptor) async throws -> AVCaptureSession {
        try await ensureVideoPermission()

        guard let uniqueID = device.avFoundationUniqueID else {
            throw CameraControlError.deviceNotConnected
        }
        guard let captureDevice = AVCaptureDevice(uniqueID: uniqueID) else {
            throw CameraControlError.deviceNotConnected
        }

        let session = AVCaptureSession()
        session.beginConfiguration()

        let input = try AVCaptureDeviceInput(device: captureDevice)
        if session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
        session.startRunning()
        return session
    }

    private func ensureVideoPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted == false {
                throw CameraControlError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraControlError.permissionDenied
        @unknown default:
            throw CameraControlError.permissionDenied
        }
    }
}
