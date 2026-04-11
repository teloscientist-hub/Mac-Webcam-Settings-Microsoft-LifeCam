import Foundation

enum CameraControlType: String, Codable, Sendable {
    case boolean
    case integerRange
    case floatRange
    case enumSelection
}
