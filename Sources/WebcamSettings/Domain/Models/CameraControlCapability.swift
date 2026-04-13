import Foundation

enum ControlCapabilitySource: String, Codable, Hashable, Sendable {
    case rawCatalog
    case simulatedFallback
}

struct CameraControlCapability: Identifiable, Codable, Hashable, Sendable {
    let key: CameraControlKey
    let displayName: String
    let type: CameraControlType
    let source: ControlCapabilitySource
    let isSupported: Bool
    let isReadable: Bool
    let isWritable: Bool
    let availabilityNote: String?
    let minValue: CameraControlValue?
    let maxValue: CameraControlValue?
    let stepValue: CameraControlValue?
    let defaultValue: CameraControlValue?
    let currentValue: CameraControlValue?
    let enumOptions: [CameraControlOption]
    let dependency: ControlDependency?

    init(
        key: CameraControlKey,
        displayName: String,
        type: CameraControlType,
        source: ControlCapabilitySource = .simulatedFallback,
        isSupported: Bool,
        isReadable: Bool,
        isWritable: Bool,
        availabilityNote: String? = nil,
        minValue: CameraControlValue?,
        maxValue: CameraControlValue?,
        stepValue: CameraControlValue?,
        defaultValue: CameraControlValue?,
        currentValue: CameraControlValue?,
        enumOptions: [CameraControlOption],
        dependency: ControlDependency?
    ) {
        self.key = key
        self.displayName = displayName
        self.type = type
        self.source = source
        self.isSupported = isSupported
        self.isReadable = isReadable
        self.isWritable = isWritable
        self.availabilityNote = availabilityNote
        self.minValue = minValue
        self.maxValue = maxValue
        self.stepValue = stepValue
        self.defaultValue = defaultValue
        self.currentValue = currentValue
        self.enumOptions = enumOptions
        self.dependency = dependency
    }

    var id: CameraControlKey { key }
}

struct CameraControlOption: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let value: String
}
