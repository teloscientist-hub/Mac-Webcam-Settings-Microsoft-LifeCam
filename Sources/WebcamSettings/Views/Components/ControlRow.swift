import SwiftUI

struct ControlRow: View {
    let capability: CameraControlCapability
    let currentValues: [CameraControlKey: CameraControlValue]
    let isWriting: Bool
    let errorMessage: String?
    let onWrite: (CameraControlKey, CameraControlValue) -> Void

    var body: some View {
        switch capability.type {
        case .boolean:
            ToggleControlRow(
                title: capability.displayName,
                isOn: boolValue ?? false,
                isEnabled: isEnabled && !isWriting,
                helperText: statusText,
                onChange: { onWrite(capability.key, .bool($0)) }
            )

        case .enumSelection:
            EnumSelectorRow(
                title: capability.displayName,
                options: capability.enumOptions,
                selectedValue: enumValue ?? capability.enumOptions.first?.value ?? "",
                isEnabled: isEnabled && !isWriting,
                helperText: statusText,
                onChange: { onWrite(capability.key, .enumCase($0)) }
            )

        case .integerRange, .floatRange:
            SliderControlRow(
                title: capability.displayName,
                value: numericValue,
                range: numericRange,
                step: numericStep,
                prefersIntegerInput: capability.type == .integerRange,
                isEnabled: isEnabled && !isWriting,
                helperText: statusText,
                onChange: { value in
                    switch capability.type {
                    case .integerRange:
                        onWrite(capability.key, .int(Int(value.rounded())))
                    case .floatRange:
                        onWrite(capability.key, .double(value))
                    case .boolean, .enumSelection:
                        break
                    }
                }
            )
        }
    }

    private var boolValue: Bool? {
        if case let .bool(value)? = currentValue {
            return value
        }
        return nil
    }

    private var enumValue: String? {
        if case let .enumCase(value)? = currentValue {
            return value
        }
        return nil
    }

    private var numericValue: Double {
        switch currentValue {
        case let .int(value):
            Double(value)
        case let .double(value):
            value
        default:
            switch capability.defaultValue {
            case let .int(value):
                Double(value)
            case let .double(value):
                value
            default:
                0
            }
        }
    }

    private var numericRange: ClosedRange<Double> {
        let minValue: Double
        let maxValue: Double

        switch capability.minValue {
        case let .int(value):
            minValue = Double(value)
        case let .double(value):
            minValue = value
        default:
            minValue = 0
        }

        switch capability.maxValue {
        case let .int(value):
            maxValue = Double(value)
        case let .double(value):
            maxValue = value
        default:
            maxValue = 100
        }

        return minValue ... maxValue
    }

    private var numericStep: Double {
        switch capability.stepValue {
        case let .int(value):
            return Double(value)
        case let .double(value):
            return value
        default:
            return capability.type == .integerRange ? 1 : 0.1
        }
    }

    private var currentValue: CameraControlValue? {
        currentValues[capability.key]
    }

    private var isEnabled: Bool {
        capability.isSupported &&
            capability.isWritable &&
            !(capability.dependency?.isDisabled(using: currentValues) ?? false)
    }

    private var helperText: String? {
        if capability.isSupported == false {
            return "Unsupported on the selected device."
        }
        if capability.isWritable == false {
            return capability.availabilityNote ?? "This control is read-only for the selected device."
        }
        if let dependency = capability.dependency, !isEnabled {
            return dependency.reason
        }
        return capability.availabilityNote
    }

    private var statusText: String? {
        if let errorMessage {
            return errorMessage
        }
        if isWriting {
            return "Applying change..."
        }
        return helperText
    }
}
