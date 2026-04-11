import AVFoundation
import Foundation

@MainActor
final class PreviewSessionController: ObservableObject {
    @Published var session: AVCaptureSession?
}
