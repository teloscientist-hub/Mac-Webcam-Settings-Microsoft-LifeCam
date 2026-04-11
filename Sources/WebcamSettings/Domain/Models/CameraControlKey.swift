import Foundation

enum CameraControlKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case exposureMode
    case exposureTime
    case brightness
    case contrast
    case saturation
    case sharpness
    case whiteBalanceAuto
    case whiteBalanceTemperature
    case powerLineFrequency
    case backlightCompensation
    case focusAuto
    case focus
    case zoom
    case pan
    case tilt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exposureMode: "Exposure Mode"
        case .exposureTime: "Exposure Time"
        case .brightness: "Brightness"
        case .contrast: "Contrast"
        case .saturation: "Saturation"
        case .sharpness: "Sharpness"
        case .whiteBalanceAuto: "Auto White Balance"
        case .whiteBalanceTemperature: "White Balance Temperature"
        case .powerLineFrequency: "Power Line Frequency"
        case .backlightCompensation: "Backlight Compensation"
        case .focusAuto: "Autofocus"
        case .focus: "Focus"
        case .zoom: "Zoom"
        case .pan: "Pan"
        case .tilt: "Tilt"
        }
    }
}
