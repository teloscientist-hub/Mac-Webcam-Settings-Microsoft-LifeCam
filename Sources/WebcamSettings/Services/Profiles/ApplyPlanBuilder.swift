import Foundation

struct ApplyPlanBuilder: Sendable {
    private let orderedStages: [[CameraControlKey]] = [
        [.whiteBalanceAuto, .focusAuto],
        [.exposureMode],
        [.powerLineFrequency],
        [.exposureTime, .whiteBalanceTemperature, .focus],
        [.brightness, .contrast, .saturation, .sharpness, .backlightCompensation],
        [.zoom, .pan, .tilt]
    ]

    func buildOrderedValues(from values: [CameraControlKey: CameraControlValue]) -> [(CameraControlKey, CameraControlValue)] {
        var ordered: [(CameraControlKey, CameraControlValue)] = []
        var remaining = values

        for stage in orderedStages {
            for key in stage {
                if let value = remaining.removeValue(forKey: key) {
                    ordered.append((key, value))
                }
            }
        }

        for key in remaining.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            if let value = remaining[key] {
                ordered.append((key, value))
            }
        }

        return ordered
    }
}
