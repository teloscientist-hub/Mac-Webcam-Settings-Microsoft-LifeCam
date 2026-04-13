import Foundation

actor SyntheticRawUVCCameraBackend: UVCCameraBackend {
    private let transport: any RawUVCTransporting
    private var cachedValuesByDeviceID: [String: [CameraControlKey: CameraControlValue]] = [:]

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
        let plans = readablePlans(for: device)

        var values = seededValues(for: device)
        var firstError: CameraControlError?
        var successCount = 0

        for plan in plans {
            do {
                let payload = try await transport.execute(plan: plan, payload: nil, device: device)
                values[plan.key] = try RawUVCBindings.decodePayload(payload, plan: plan)
                successCount += 1
            } catch let error as CameraControlError {
                if firstError == nil {
                    firstError = error
                }
            } catch {
                if firstError == nil {
                    firstError = .backendFailure(error.localizedDescription)
                }
            }
        }

        cachedValuesByDeviceID[device.id] = values

        if successCount == 0, let firstError {
            throw firstError
        }

        return values
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        if let plan = RawUVCBindings.requestPlan(for: key, device: device, operation: .setCurrent) {
            let payload = try RawUVCBindings.encodePayload(for: value, plan: plan)
            _ = try await transport.execute(plan: plan, payload: payload, device: device)
            var values = seededValues(for: device)
            values[key] = value
            cachedValuesByDeviceID[device.id] = values
            return
        }

        throw CameraControlError.controlUnsupported(key)
    }

    private func seededValues(for device: CameraDeviceDescriptor) -> [CameraControlKey: CameraControlValue] {
        var values = cachedValuesByDeviceID[device.id] ?? [:]
        let capabilities = BackendCapabilityCatalog.capabilities(
            for: device,
            supportedKeys: Set(RawUVCBindings.mappedControls(for: device).map(\.key))
        )

        for capability in capabilities {
            guard let currentValue = capability.currentValue else { continue }
            if values[capability.key] == nil {
                values[capability.key] = currentValue
            }
        }

        return values
    }

    private func readablePlans(for device: CameraDeviceDescriptor) -> [RawUVCBindings.RequestPlan] {
        let supportedKeys = BackendCapabilityCatalog.backendProfile(for: device).supportedKeys
        return RawUVCBindings
            .mappedControls(for: device)
            .filter { supportedKeys.contains($0.key) && $0.isReadable }
            .compactMap { RawUVCBindings.requestPlan(for: $0.key, device: device, operation: .getCurrent) }
    }
}
