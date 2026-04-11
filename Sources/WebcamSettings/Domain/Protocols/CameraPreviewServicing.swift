@preconcurrency import AVFoundation
import Foundation

@MainActor
protocol CameraPreviewServicing: Sendable {
    func startPreview(for device: CameraDeviceDescriptor) async throws -> AVCaptureSession
    func stopPreview() async
}
