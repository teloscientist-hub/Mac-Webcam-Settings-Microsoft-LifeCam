import Foundation

@MainActor
final class AdvancedTabViewModel: ObservableObject {
    @Published private(set) var capabilities: [CameraControlCapability] = []
    @Published private(set) var currentValues: [CameraControlKey: CameraControlValue] = [:]

    private let keys: Set<CameraControlKey> = [
        .powerLineFrequency, .backlightCompensation, .focusAuto,
        .focus, .zoom, .pan, .tilt
    ]

    func update(capabilities: [CameraControlCapability], currentValues: [CameraControlKey: CameraControlValue]) {
        self.capabilities = capabilities.filter { keys.contains($0.key) }
        self.currentValues = currentValues
    }
}
