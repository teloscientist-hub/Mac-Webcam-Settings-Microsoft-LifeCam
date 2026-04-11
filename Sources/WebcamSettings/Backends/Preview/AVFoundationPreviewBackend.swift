@preconcurrency import AVFoundation
import Foundation

@MainActor
final class AVFoundationPreviewBackend {
    func startPreview(for device: CameraDeviceDescriptor) async throws -> AVCaptureSession {
        guard let uniqueID = device.avFoundationUniqueID else {
            throw CameraControlError.deviceNotConnected
        }
        guard let captureDevice = AVCaptureDevice(uniqueID: uniqueID) else {
            throw CameraControlError.deviceNotConnected
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let input = try AVCaptureDeviceInput(device: captureDevice)
        if session.canAddInput(input) {
            session.addInput(input)
        }
        session.startRunning()
        return session
    }
}
