import Foundation

actor SyntheticRawUVCCameraBackend: UVCCameraBackend {
    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [BackendControlCapability] {
        guard RawUVCBindings.canAttemptDirectAccess(for: device) else {
            throw CameraControlError.backendFailure("Device is not a raw UVC candidate.")
        }

        let mappedKeys = Set(RawUVCBindings.mappedControls(for: device).map(\.key))
        return BackendCapabilityCatalog.capabilities(for: device, supportedKeys: mappedKeys)
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey : CameraControlValue] {
        let mappedControls = RawUVCBindings.mappedControls(for: device)
        throw CameraControlError.backendFailure("Direct UVC reads not implemented yet. Planned raw mappings: \(mappedControls.count).")
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        _ = value
        if let descriptor = RawUVCBindings.descriptor(for: key, device: device) {
            throw CameraControlError.backendFailure(
                "Direct UVC write not implemented for \(key.displayName) (entity \(descriptor.entity.rawValue), selector 0x\(String(format: "%02X", descriptor.selector)), unit \(descriptor.unitID))."
            )
        }

        throw CameraControlError.controlUnsupported(key)
    }
}
