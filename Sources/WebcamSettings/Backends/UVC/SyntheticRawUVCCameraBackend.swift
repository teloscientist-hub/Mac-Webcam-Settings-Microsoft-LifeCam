import Foundation

actor SyntheticRawUVCCameraBackend: UVCCameraBackend {
    private let transport: any RawUVCTransporting

    init(transport: any RawUVCTransporting = UnavailableRawUVCTransport()) {
        self.transport = transport
    }

    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [BackendControlCapability] {
        guard RawUVCBindings.canAttemptDirectAccess(for: device) else {
            throw CameraControlError.backendFailure("Device is not a raw UVC candidate.")
        }

        let mappedKeys = Set(RawUVCBindings.mappedControls(for: device).map(\.key))
        return BackendCapabilityCatalog.capabilities(for: device, supportedKeys: mappedKeys).map { capability in
            BackendControlCapability(
                key: capability.key,
                type: capability.type,
                source: .rawCatalog,
                isSupported: capability.isSupported,
                isReadable: capability.isReadable,
                isWritable: capability.isWritable,
                minValue: capability.minValue,
                maxValue: capability.maxValue,
                stepValue: capability.stepValue,
                defaultValue: capability.defaultValue,
                currentValue: capability.currentValue,
                enumOptions: capability.enumOptions
            )
        }
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey : CameraControlValue] {
        let plans = RawUVCBindings
            .mappedControls(for: device)
            .compactMap { RawUVCBindings.requestPlan(for: $0.key, device: device, operation: .getCurrent) }

        var values: [CameraControlKey: CameraControlValue] = [:]
        for plan in plans {
            let payload = try await transport.execute(plan: plan, payload: nil, device: device)
            values[plan.key] = try RawUVCBindings.decodePayload(payload, plan: plan)
        }

        return values
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        if let plan = RawUVCBindings.requestPlan(for: key, device: device, operation: .setCurrent) {
            let payload = try RawUVCBindings.encodePayload(for: value, plan: plan)
            _ = try await transport.execute(plan: plan, payload: payload, device: device)
            return
        }

        throw CameraControlError.controlUnsupported(key)
    }
}
