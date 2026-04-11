import Foundation

enum RawUVCBindings {
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

    static let isImplemented = false

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
            return "Capabilities from raw mapping catalog; live reads and writes still fall back until direct UVC transport is implemented."
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
        .init(key: .brightness, entity: .processingUnit, selector: 0x02, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .contrast, entity: .processingUnit, selector: 0x03, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .saturation, entity: .processingUnit, selector: 0x07, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .sharpness, entity: .processingUnit, selector: 0x08, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .whiteBalanceAuto, entity: .processingUnit, selector: 0x0B, unitID: 0x02, length: 1, valueType: .boolean, isReadable: true, isWritable: true),
        .init(key: .whiteBalanceTemperature, entity: .processingUnit, selector: 0x0A, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true),
        .init(key: .powerLineFrequency, entity: .processingUnit, selector: 0x05, unitID: 0x02, length: 1, valueType: .enumSelection, isReadable: true, isWritable: true),
        .init(key: .backlightCompensation, entity: .processingUnit, selector: 0x01, unitID: 0x02, length: 2, valueType: .integerRange, isReadable: true, isWritable: true)
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
}
