import Foundation

struct CameraControlCapability: Identifiable, Codable, Hashable, Sendable {
    let key: CameraControlKey
    let displayName: String
    let type: CameraControlType
    let isSupported: Bool
    let isReadable: Bool
    let isWritable: Bool
    let minValue: CameraControlValue?
    let maxValue: CameraControlValue?
    let stepValue: CameraControlValue?
    let defaultValue: CameraControlValue?
    let currentValue: CameraControlValue?
    let enumOptions: [CameraControlOption]
    let dependency: ControlDependency?

    var id: CameraControlKey { key }
}

struct CameraControlOption: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let value: String
}
