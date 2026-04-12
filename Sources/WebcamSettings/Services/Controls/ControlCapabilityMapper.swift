import Foundation

struct ControlCapabilityMapper: Sendable {
    func mapBackendCapabilities(_ backendCapabilities: [BackendControlCapability]) -> [CameraControlCapability] {
        backendCapabilities.map { capability in
            CameraControlCapability(
                key: capability.key,
                displayName: capability.key.displayName,
                type: capability.type,
                source: capability.source,
                isSupported: capability.isSupported,
                isReadable: capability.isReadable,
                isWritable: capability.isWritable,
                minValue: capability.minValue,
                maxValue: capability.maxValue,
                stepValue: capability.stepValue,
                defaultValue: capability.defaultValue,
                currentValue: capability.currentValue,
                enumOptions: capability.enumOptions,
                dependency: dependency(for: capability.key)
            )
        }
    }

    func buildPlaceholderBackendCapabilities() -> [BackendControlCapability] {
        let sliderKeys: [CameraControlKey] = [
            .exposureTime, .brightness, .contrast, .saturation, .sharpness,
            .whiteBalanceTemperature, .backlightCompensation, .focus, .zoom, .pan, .tilt
        ]

        let sliderCapabilities = sliderKeys.map { key in
            BackendControlCapability(
                key: key,
                type: .integerRange,
                source: .simulatedFallback,
                isSupported: true,
                isReadable: true,
                isWritable: true,
                minValue: .int(0),
                maxValue: .int(100),
                stepValue: .int(1),
                defaultValue: .int(50),
                currentValue: .int(50),
                enumOptions: []
            )
        }

        let enumCapabilities: [BackendControlCapability] = [
            BackendControlCapability(
                key: .exposureMode,
                type: .enumSelection,
                source: .simulatedFallback,
                isSupported: true,
                isReadable: true,
                isWritable: true,
                minValue: nil,
                maxValue: nil,
                stepValue: nil,
                defaultValue: .enumCase("auto"),
                currentValue: .enumCase("auto"),
                enumOptions: [
                    .init(id: "auto", title: "Auto", value: "auto"),
                    .init(id: "manual", title: "Manual", value: "manual")
                ]
            ),
            BackendControlCapability(
                key: .powerLineFrequency,
                type: .enumSelection,
                source: .simulatedFallback,
                isSupported: true,
                isReadable: true,
                isWritable: true,
                minValue: nil,
                maxValue: nil,
                stepValue: nil,
                defaultValue: .enumCase("auto"),
                currentValue: .enumCase("auto"),
                enumOptions: [
                    .init(id: "disabled", title: "Disabled", value: "disabled"),
                    .init(id: "50hz", title: "50 Hz", value: "50hz"),
                    .init(id: "60hz", title: "60 Hz", value: "60hz"),
                    .init(id: "auto", title: "Auto", value: "auto")
                ]
            ),
            BackendControlCapability(
                key: .whiteBalanceAuto,
                type: .boolean,
                source: .simulatedFallback,
                isSupported: true,
                isReadable: true,
                isWritable: true,
                minValue: nil,
                maxValue: nil,
                stepValue: nil,
                defaultValue: .bool(true),
                currentValue: .bool(true),
                enumOptions: []
            ),
            BackendControlCapability(
                key: .focusAuto,
                type: .boolean,
                source: .simulatedFallback,
                isSupported: true,
                isReadable: true,
                isWritable: true,
                minValue: nil,
                maxValue: nil,
                stepValue: nil,
                defaultValue: .bool(true),
                currentValue: .bool(true),
                enumOptions: []
            )
        ]

        return enumCapabilities + sliderCapabilities
    }

    private func dependency(for key: CameraControlKey) -> ControlDependency? {
        switch key {
        case .whiteBalanceTemperature:
            ControlDependency(controllingKey: .whiteBalanceAuto, disablingValues: [.bool(true)], reason: "Disabled while auto white balance is enabled.")
        case .focus:
            ControlDependency(controllingKey: .focusAuto, disablingValues: [.bool(true)], reason: "Disabled while autofocus is enabled.")
        case .exposureTime:
            ControlDependency(controllingKey: .exposureMode, disablingValues: [.enumCase("auto")], reason: "Disabled while exposure mode is automatic.")
        default:
            nil
        }
    }
}
