import Foundation

struct BackendControlCapability: Sendable {
    let key: CameraControlKey
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

    init(
        key: CameraControlKey,
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
        enumOptions: [CameraControlOption]
    ) {
        self.key = key
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
    }
}

struct BackendDeviceProfile: Sendable {
    let name: String
    let supportedKeys: Set<CameraControlKey>
    let overrides: [CameraControlKey: CapabilityOverride]

    struct CapabilityOverride: Sendable {
        let minValue: CameraControlValue?
        let maxValue: CameraControlValue?
        let stepValue: CameraControlValue?
        let defaultValue: CameraControlValue?
        let currentValue: CameraControlValue?
        let enumOptions: [CameraControlOption]?
    }
}

protocol UVCCameraBackend: Sendable {
    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [BackendControlCapability]
    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue]
    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws
}

enum BackendCapabilityCatalog {
    static func capabilities(for device: CameraDeviceDescriptor, supportedKeys: Set<CameraControlKey>? = nil) -> [BackendControlCapability] {
        let mapper = ControlCapabilityMapper()
        let baseCapabilities = mapper.buildPlaceholderBackendCapabilities()
        let profile = backendProfile(for: device)
        let supported = supportedKeys ?? profile.supportedKeys

        return baseCapabilities.map { capability in
            let isSupported = supported.contains(capability.key)
            let override = profile.overrides[capability.key]
            return BackendControlCapability(
                key: capability.key,
                type: capability.type,
                source: capability.source,
                isSupported: isSupported,
                isReadable: isSupported,
                isWritable: isSupported,
                availabilityNote: nil,
                minValue: override?.minValue ?? capability.minValue,
                maxValue: override?.maxValue ?? capability.maxValue,
                stepValue: override?.stepValue ?? capability.stepValue,
                defaultValue: override?.defaultValue ?? capability.defaultValue,
                currentValue: isSupported ? (override?.currentValue ?? capability.currentValue) : nil,
                enumOptions: override?.enumOptions ?? capability.enumOptions
            )
        }
    }

    static func backendProfile(for device: CameraDeviceDescriptor) -> BackendDeviceProfile {
        if device.vendorID == 0x045E, device.productID == 0x0772 {
            return .lifeCamStudio
        }

        if device.name.localizedCaseInsensitiveContains("LifeCam") || device.model?.localizedCaseInsensitiveContains("LifeCam") == true {
            return .lifeCamStudio
        }
        return .genericUSB
    }
}

actor InMemoryUVCCameraBackend: UVCCameraBackend {
    private var deviceStates: [String: [CameraControlKey: CameraControlValue]] = [:]

    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [BackendControlCapability] {
        let capabilities = seedCapabilities(for: device)
        if deviceStates[device.id] == nil {
            deviceStates[device.id] = Dictionary(uniqueKeysWithValues: capabilities.compactMap { capability in
                guard let value = capability.currentValue else { return nil }
                return (capability.key, value)
            })
        }

        let currentState = deviceStates[device.id] ?? [:]
        return capabilities.map { capability in
            BackendControlCapability(
                key: capability.key,
                type: capability.type,
                source: capability.source,
                isSupported: capability.isSupported,
                isReadable: capability.isReadable,
                isWritable: capability.isWritable,
                availabilityNote: capability.availabilityNote,
                minValue: capability.minValue,
                maxValue: capability.maxValue,
                stepValue: capability.stepValue,
                defaultValue: capability.defaultValue,
                currentValue: currentState[capability.key] ?? capability.currentValue,
                enumOptions: capability.enumOptions
            )
        }
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        if deviceStates[device.id] == nil {
            _ = try await fetchCapabilities(for: device)
        }
        return deviceStates[device.id] ?? [:]
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        let capabilities = try await fetchCapabilities(for: device)
        guard let capability = capabilities.first(where: { $0.key == key && $0.isSupported }) else {
            throw CameraControlError.controlUnsupported(key)
        }
        guard capability.isWritable else {
            throw CameraControlError.controlWriteFailed(key)
        }

        var values = deviceStates[device.id] ?? [:]
        try validateDependencyState(for: key, currentValues: values)
        values[key] = value

        // Simulate automatic modes suppressing their dependent manual values.
        switch (key, value) {
        case (.whiteBalanceAuto, .bool(true)):
            values[.whiteBalanceTemperature] = capabilityValue(for: .whiteBalanceTemperature, device: device)?.defaultValue ?? .int(50)
        case (.focusAuto, .bool(true)):
            values[.focus] = capabilityValue(for: .focus, device: device)?.defaultValue ?? .int(50)
        case (.exposureMode, .enumCase("auto")):
            values[.exposureTime] = capabilityValue(for: .exposureTime, device: device)?.defaultValue ?? .int(50)
        default:
            break
        }

        deviceStates[device.id] = values
    }

    private func validateDependencyState(for key: CameraControlKey, currentValues: [CameraControlKey: CameraControlValue]) throws {
        switch key {
        case .whiteBalanceTemperature:
            if currentValues[.whiteBalanceAuto] == .bool(true) {
                throw CameraControlError.invalidValue(key)
            }
        case .focus:
            if currentValues[.focusAuto] == .bool(true) {
                throw CameraControlError.invalidValue(key)
            }
        case .exposureTime:
            if currentValues[.exposureMode] == .enumCase("auto") {
                throw CameraControlError.invalidValue(key)
            }
        default:
            break
        }
    }

    private func capabilityValue(for key: CameraControlKey, device: CameraDeviceDescriptor) -> BackendControlCapability? {
        seedCapabilities(for: device).first(where: { $0.key == key })
    }

    private func seedCapabilities(for device: CameraDeviceDescriptor) -> [BackendControlCapability] {
        BackendCapabilityCatalog.capabilities(for: device)
    }
}

private extension BackendDeviceProfile {
    static let lifeCamStudio = BackendDeviceProfile(
        name: "Microsoft LifeCam Studio",
        supportedKeys: [
            .exposureMode, .exposureTime,
            .brightness, .contrast, .saturation, .sharpness,
            .whiteBalanceAuto, .whiteBalanceTemperature,
            .powerLineFrequency, .backlightCompensation,
            .focusAuto, .focus, .zoom
        ],
        overrides: [
            .exposureTime: .init(minValue: .int(1), maxValue: .int(10_000), stepValue: .int(1), defaultValue: .int(156), currentValue: .int(156), enumOptions: nil),
            .brightness: .init(minValue: .int(30), maxValue: .int(255), stepValue: .int(1), defaultValue: .int(133), currentValue: .int(133), enumOptions: nil),
            .contrast: .init(minValue: .int(0), maxValue: .int(10), stepValue: .int(1), defaultValue: .int(5), currentValue: .int(1), enumOptions: nil),
            .saturation: .init(minValue: .int(0), maxValue: .int(200), stepValue: .int(1), defaultValue: .int(103), currentValue: .int(95), enumOptions: nil),
            .sharpness: .init(minValue: .int(0), maxValue: .int(50), stepValue: .int(1), defaultValue: .int(25), currentValue: .int(50), enumOptions: nil),
            .whiteBalanceTemperature: .init(minValue: .int(2500), maxValue: .int(10_000), stepValue: .int(1), defaultValue: .int(4500), currentValue: .int(3700), enumOptions: nil),
            .backlightCompensation: .init(minValue: .int(0), maxValue: .int(10), stepValue: .int(1), defaultValue: .int(0), currentValue: .int(4), enumOptions: nil),
            .focus: .init(minValue: .int(0), maxValue: .int(40), stepValue: .int(1), defaultValue: .int(0), currentValue: .int(16), enumOptions: nil),
            .zoom: .init(minValue: .int(0), maxValue: .int(317), stepValue: .int(1), defaultValue: .int(0), currentValue: .int(0), enumOptions: nil),
            .powerLineFrequency: .init(minValue: nil, maxValue: nil, stepValue: nil, defaultValue: .enumCase("60hz"), currentValue: .enumCase("60hz"), enumOptions: [
                .init(id: "disabled", title: "Disabled", value: "disabled"),
                .init(id: "50hz", title: "50 Hz", value: "50hz"),
                .init(id: "60hz", title: "60 Hz", value: "60hz")
            ]),
            .whiteBalanceAuto: .init(minValue: nil, maxValue: nil, stepValue: nil, defaultValue: .bool(true), currentValue: .bool(true), enumOptions: nil),
            .focusAuto: .init(minValue: nil, maxValue: nil, stepValue: nil, defaultValue: .bool(true), currentValue: .bool(false), enumOptions: nil),
            .exposureMode: .init(minValue: nil, maxValue: nil, stepValue: nil, defaultValue: .enumCase("auto"), currentValue: .enumCase("manual"), enumOptions: [
                .init(id: "auto", title: "Auto", value: "auto"),
                .init(id: "manual", title: "Manual", value: "manual")
            ])
        ]
    )

    static let genericUSB = BackendDeviceProfile(
        name: "Generic USB Camera",
        supportedKeys: [
            .exposureMode, .exposureTime, .brightness, .contrast, .saturation,
            .sharpness, .whiteBalanceAuto, .whiteBalanceTemperature,
            .powerLineFrequency, .focusAuto, .focus
        ],
        overrides: [
            .exposureTime: .init(minValue: .int(1), maxValue: .int(100), stepValue: .int(1), defaultValue: .int(40), currentValue: .int(40), enumOptions: nil),
            .brightness: .init(minValue: .int(0), maxValue: .int(100), stepValue: .int(1), defaultValue: .int(50), currentValue: .int(50), enumOptions: nil),
            .whiteBalanceTemperature: .init(minValue: .int(2800), maxValue: .int(6500), stepValue: .int(100), defaultValue: .int(4200), currentValue: .int(4200), enumOptions: nil),
            .focus: .init(minValue: .int(0), maxValue: .int(30), stepValue: .int(1), defaultValue: .int(10), currentValue: .int(10), enumOptions: nil)
        ]
    )
}
