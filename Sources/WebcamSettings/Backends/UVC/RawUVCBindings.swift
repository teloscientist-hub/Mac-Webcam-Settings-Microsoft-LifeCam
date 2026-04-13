import Foundation

enum RawUVCBindings {
    struct RequestPlan: Sendable, Equatable {
        enum Operation: String, Sendable {
            case getCurrent
            case setCurrent
        }

        let key: CameraControlKey
        let operation: Operation
        let entity: ControlDescriptor.Entity
        let selector: UInt8
        let unitID: UInt8
        let expectedLength: Int
        let valueType: CameraControlType
    }

    enum PayloadCodecError: LocalizedError, Equatable {
        case unsupportedControl(CameraControlKey)
        case invalidValue(CameraControlKey)
        case invalidPayloadLength(CameraControlKey, expected: Int, actual: Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedControl(key):
                return "No raw payload codec is available for \(key.displayName)."
            case let .invalidValue(key):
                return "The provided value could not be encoded for \(key.displayName)."
            case let .invalidPayloadLength(key, expected, actual):
                return "Unexpected payload length for \(key.displayName): expected \(expected), got \(actual)."
            }
        }
    }

    struct ControlDescriptor: Sendable, Equatable {
        enum Entity: String, Sendable {
            case cameraTerminal
            case processingUnit
        }

        let key: CameraControlKey
        let entity: Entity
        let selector: UInt8
        let unitID: UInt8
        let length: Int
        let valueType: CameraControlType
        let isReadable: Bool
        let isWritable: Bool
    }

    static let isImplemented = true

    static func canAttemptDirectAccess(for device: CameraDeviceDescriptor) -> Bool {
        guard device.transportType == .usb else { return false }
        guard device.vendorID != nil || device.productID != nil || device.backendIdentifier != nil else { return false }
        return true
    }

    static func mappedControls(for device: CameraDeviceDescriptor) -> [ControlDescriptor] {
        if device.vendorID == 0x045E, device.productID == 0x0772 {
            return lifeCamStudioDescriptors
        }

        if device.name.localizedCaseInsensitiveContains("LifeCam") || device.model?.localizedCaseInsensitiveContains("LifeCam") == true {
            return lifeCamStudioDescriptors
        }

        if device.transportType == .usb {
            return genericUSBDescriptors
        }

        return []
    }

    static func descriptor(for key: CameraControlKey, device: CameraDeviceDescriptor) -> ControlDescriptor? {
        mappedControls(for: device).first(where: { $0.key == key })
    }

    static func requestPlan(
        for key: CameraControlKey,
        device: CameraDeviceDescriptor,
        operation: RequestPlan.Operation
    ) -> RequestPlan? {
        guard let descriptor = descriptor(for: key, device: device) else {
            return nil
        }

        switch operation {
        case .getCurrent where descriptor.isReadable == false:
            return nil
        case .setCurrent where descriptor.isWritable == false:
            return nil
        default:
            return RequestPlan(
                key: key,
                operation: operation,
                entity: descriptor.entity,
                selector: descriptor.selector,
                unitID: descriptor.unitID,
                expectedLength: descriptor.length,
                valueType: descriptor.valueType
            )
        }
    }

    static func encodePayload(
        for value: CameraControlValue,
        plan: RequestPlan
    ) throws -> Data {
        switch plan.key {
        case .brightness, .contrast, .saturation, .sharpness, .whiteBalanceTemperature, .backlightCompensation, .focus, .zoom:
            guard case let .int(intValue) = value else {
                throw PayloadCodecError.invalidValue(plan.key)
            }
            return try encodeSignedLittleEndian(intValue, byteCount: plan.expectedLength, key: plan.key)

        case .exposureTime, .pan, .tilt:
            guard case let .int(intValue) = value else {
                throw PayloadCodecError.invalidValue(plan.key)
            }
            return try encodeSignedLittleEndian(intValue, byteCount: plan.expectedLength, key: plan.key)

        case .whiteBalanceAuto, .focusAuto:
            guard case let .bool(boolValue) = value else {
                throw PayloadCodecError.invalidValue(plan.key)
            }
            return Data([boolValue ? 1 : 0])

        case .exposureMode:
            guard case let .enumCase(mode) = value else {
                throw PayloadCodecError.invalidValue(plan.key)
            }
            let encoded: UInt8
            switch mode {
            case "auto":
                encoded = 0x08
            case "manual":
                encoded = 0x01
            default:
                throw PayloadCodecError.invalidValue(plan.key)
            }
            return Data([encoded])

        case .powerLineFrequency:
            guard case let .enumCase(mode) = value else {
                throw PayloadCodecError.invalidValue(plan.key)
            }
            let encoded: UInt8
            switch mode {
            case "disabled":
                encoded = 0
            case "50hz":
                encoded = 1
            case "60hz":
                encoded = 2
            case "auto":
                encoded = 3
            default:
                throw PayloadCodecError.invalidValue(plan.key)
            }
            return Data([encoded])
        }
    }

    static func decodePayload(
        _ payload: Data,
        plan: RequestPlan
    ) throws -> CameraControlValue {
        guard payload.count == plan.expectedLength else {
            throw PayloadCodecError.invalidPayloadLength(plan.key, expected: plan.expectedLength, actual: payload.count)
        }

        switch plan.key {
        case .brightness, .contrast, .saturation, .sharpness, .whiteBalanceTemperature, .backlightCompensation, .focus, .zoom,
             .exposureTime, .pan, .tilt:
            return .int(try decodeSignedLittleEndian(payload, key: plan.key))

        case .whiteBalanceAuto, .focusAuto:
            return .bool(payload.first == 1)

        case .exposureMode:
            switch payload.first {
            case 0x08:
                return .enumCase("auto")
            case 0x01:
                return .enumCase("manual")
            default:
                throw PayloadCodecError.invalidValue(plan.key)
            }

        case .powerLineFrequency:
            switch payload.first {
            case 0:
                return .enumCase("disabled")
            case 1:
                return .enumCase("50hz")
            case 2:
                return .enumCase("60hz")
            case 3:
                return .enumCase("auto")
            default:
                throw PayloadCodecError.invalidValue(plan.key)
            }
        }
    }

    static func mappingSummary(for device: CameraDeviceDescriptor?) -> String {
        guard let device else {
            return "No raw UVC device selected"
        }

        let descriptors = mappedControls(for: device)
        guard descriptors.isEmpty == false else {
            return "No planned raw mappings for selected device"
        }

        let processingCount = descriptors.filter { $0.entity == .processingUnit }.count
        let terminalCount = descriptors.filter { $0.entity == .cameraTerminal }.count
        return "\(descriptors.count) mapped controls (\(processingCount) processing, \(terminalCount) camera terminal)"
    }

    static func pipelineSummary(for device: CameraDeviceDescriptor?) -> String {
        guard let device else {
            return "No control pipeline active"
        }

        if canAttemptDirectAccess(for: device) {
            return "Capabilities come from the raw mapping catalog, and live device requests now route through IOUSBHost-based raw transport."
        }

        if device.transportType == .usb {
            return "USB device detected, but raw control transport is not ready for this camera identity."
        }

        return "Using non-raw fallback control pipeline."
    }

    static func backendSummary(for device: CameraDeviceDescriptor?) -> String {
        guard let device else {
            return isImplemented ? "Raw UVC backend available" : "In-memory UVC backend"
        }

        let mappedControlCount = mappedControls(for: device).count
        if canAttemptDirectAccess(for: device) {
            let status = isImplemented ? "ready" : "planned"
            return "Raw UVC candidate (\(mappedControlCount) mapped controls, \(status))"
        }

        if device.transportType == .usb {
            return "In-memory UVC backend (\(mappedControlCount) planned mappings)"
        }

        return "In-memory UVC backend"
    }

    private static let lifeCamStudioDescriptors: [ControlDescriptor] = [
        .init(key: .exposureMode, entity: .cameraTerminal, selector: 0x02, unitID: 0x01, length: 1, valueType: .enumSelection, isReadable: true, isWritable: true),
        .init(key: .exposureTime, entity: .cameraTerminal, selector: 0x04, unitID: 0x01, length: 4, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .focusAuto, entity: .cameraTerminal, selector: 0x08, unitID: 0x01, length: 1, valueType: .boolean, isReadable: true, isWritable: true),
        .init(key: .focus, entity: .cameraTerminal, selector: 0x06, unitID: 0x01, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .zoom, entity: .cameraTerminal, selector: 0x0B, unitID: 0x01, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .pan, entity: .cameraTerminal, selector: 0x0D, unitID: 0x01, length: 4, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .tilt, entity: .cameraTerminal, selector: 0x0D, unitID: 0x01, length: 4, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .brightness, entity: .processingUnit, selector: 0x02, unitID: 0x04, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .contrast, entity: .processingUnit, selector: 0x03, unitID: 0x04, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .saturation, entity: .processingUnit, selector: 0x07, unitID: 0x04, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .sharpness, entity: .processingUnit, selector: 0x08, unitID: 0x04, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .whiteBalanceAuto, entity: .processingUnit, selector: 0x0B, unitID: 0x04, length: 1, valueType: .boolean, isReadable: true, isWritable: true),
        .init(key: .whiteBalanceTemperature, entity: .processingUnit, selector: 0x0A, unitID: 0x04, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .powerLineFrequency, entity: .processingUnit, selector: 0x05, unitID: 0x04, length: 1, valueType: .enumSelection, isReadable: true, isWritable: true),
        .init(key: .backlightCompensation, entity: .processingUnit, selector: 0x01, unitID: 0x04, length: 2, valueType: .integerRange, isReadable: true, isWritable: true)
    ]

    private static let genericUSBDescriptors: [ControlDescriptor] = [
        .init(key: .brightness, entity: .processingUnit, selector: 0x02, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .contrast, entity: .processingUnit, selector: 0x03, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .saturation, entity: .processingUnit, selector: 0x07, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .sharpness, entity: .processingUnit, selector: 0x08, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .whiteBalanceAuto, entity: .processingUnit, selector: 0x0B, unitID: 0x02, length: 1, valueType: .boolean, isReadable: true, isWritable: true),
        .init(key: .whiteBalanceTemperature, entity: .processingUnit, selector: 0x0A, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .powerLineFrequency, entity: .processingUnit, selector: 0x05, unitID: 0x02, length: 1, valueType: .enumSelection, isReadable: true, isWritable: true),
        .init(key: .focusAuto, entity: .cameraTerminal, selector: 0x08, unitID: 0x01, length: 1, valueType: .boolean, isReadable: true, isWritable: true),
        .init(key: .focus, entity: .cameraTerminal, selector: 0x06, unitID: 0x01, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .exposureMode, entity: .cameraTerminal, selector: 0x02, unitID: 0x01, length: 1, valueType: .enumSelection, isReadable: true, isWritable: true),
        .init(key: .exposureTime, entity: .cameraTerminal, selector: 0x04, unitID: 0x01, length: 4, valueType: .integerRange, isReadable: true, isWritable: true)
    ]

    private static func encodeSignedLittleEndian(_ value: Int, byteCount: Int, key: CameraControlKey) throws -> Data {
        switch byteCount {
        case 1:
            guard let encoded = Int8(exactly: value) else {
                throw PayloadCodecError.invalidValue(key)
            }
            return Data([UInt8(bitPattern: encoded)])
        case 2:
            guard let encoded = Int16(exactly: value) else {
                throw PayloadCodecError.invalidValue(key)
            }
            let littleEndian = encoded.littleEndian
            return withUnsafeBytes(of: littleEndian) { Data($0) }
        case 4:
            guard let encoded = Int32(exactly: value) else {
                throw PayloadCodecError.invalidValue(key)
            }
            let littleEndian = encoded.littleEndian
            return withUnsafeBytes(of: littleEndian) { Data($0) }
        default:
            throw PayloadCodecError.unsupportedControl(key)
        }
    }

    private static func decodeSignedLittleEndian(_ payload: Data, key: CameraControlKey) throws -> Int {
        switch payload.count {
        case 1:
            guard let byte = payload.first else {
                throw PayloadCodecError.invalidPayloadLength(key, expected: 1, actual: 0)
            }
            return Int(Int8(bitPattern: byte))
        case 2:
            let value = payload.withUnsafeBytes { rawBuffer in
                rawBuffer.load(as: Int16.self)
            }
            return Int(Int16(littleEndian: value))
        case 4:
            let value = payload.withUnsafeBytes { rawBuffer in
                rawBuffer.load(as: Int32.self)
            }
            return Int(Int32(littleEndian: value))
        default:
            throw PayloadCodecError.unsupportedControl(key)
        }
    }
}
