import Foundation

enum CameraControlError: LocalizedError, Equatable, Sendable {
    case deviceNotConnected
    case deviceBusy
    case controlUnsupported(CameraControlKey)
    case controlReadFailed(CameraControlKey)
    case controlWriteFailed(CameraControlKey)
    case invalidValue(CameraControlKey)
    case backendFailure(String)
    case permissionDenied
    case timedOut

    var errorDescription: String? {
        switch self {
        case .deviceNotConnected:
            "The selected camera is not connected."
        case .deviceBusy:
            "The selected camera is busy."
        case let .controlUnsupported(key):
            "\(key.displayName) is not supported by the current device."
        case let .controlReadFailed(key):
            "Failed to read \(key.displayName)."
        case let .controlWriteFailed(key):
            "Failed to write \(key.displayName)."
        case let .invalidValue(key):
            "The provided value for \(key.displayName) is invalid."
        case let .backendFailure(message):
            "Backend failure: \(message)"
        case .permissionDenied:
            "Camera permission was denied."
        case .timedOut:
            "The operation timed out."
        }
    }
}
