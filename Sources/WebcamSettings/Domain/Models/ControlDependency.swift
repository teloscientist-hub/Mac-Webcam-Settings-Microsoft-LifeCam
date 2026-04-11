import Foundation

struct ControlDependency: Codable, Hashable, Sendable {
    let controllingKey: CameraControlKey
    let disablingValues: [CameraControlValue]
    let reason: String

    func isDisabled(using values: [CameraControlKey: CameraControlValue]) -> Bool {
        guard let currentValue = values[controllingKey] else {
            return false
        }
        return disablingValues.contains(currentValue)
    }
}
