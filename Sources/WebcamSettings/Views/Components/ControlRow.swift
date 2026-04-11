import SwiftUI

struct ControlRow: View {
    let capability: CameraControlCapability
    let currentValue: CameraControlValue?
    let onWrite: (CameraControlKey, CameraControlValue) -> Void

    var body: some View {
        switch capability.type {
        case .boolean:
            Toggle(capability.displayName, isOn: Binding(
                get: { boolValue ?? false },
                set: { onWrite(capability.key, .bool($0)) }
            ))
            .padding(12)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))

        case .enumSelection:
            EnumSelectorRow(
                title: capability.displayName,
                options: capability.enumOptions,
                selectedValue: enumValue ?? capability.enumOptions.first?.value ?? "",
                isEnabled: true,
                onChange: { onWrite(capability.key, .enumCase($0)) }
            )

        case .integerRange, .floatRange:
            SliderControlRow(
                title: capability.displayName,
                value: numericValue,
                range: numericRange,
                isEnabled: true,
                onChange: { onWrite(capability.key, .double($0)) }
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
}
