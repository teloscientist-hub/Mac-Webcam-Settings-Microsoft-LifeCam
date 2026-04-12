import Foundation

actor UnavailableRawUVCCameraBackend: UVCCameraBackend {
    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [BackendControlCapability] {
        let mappedControls = RawUVCBindings.mappedControls(for: device)
        throw CameraControlError.backendFailure("Direct UVC backend is not implemented yet. Planned raw mappings: \(mappedControls.count).")
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        let mappedControls = RawUVCBindings.mappedControls(for: device)
        throw CameraControlError.backendFailure("Direct UVC backend is not implemented yet. Planned raw mappings: \(mappedControls.count).")
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        _ = value
        if let plan = RawUVCBindings.requestPlan(for: key, device: device, operation: .setCurrent) {
            throw CameraControlError.backendFailure(
                "Direct UVC write not implemented for \(key.displayName) (entity \(plan.entity.rawValue), selector 0x\(String(format: "%02X", plan.selector)), unit \(plan.unitID), len \(plan.expectedLength))."
            )
        }

        throw CameraControlError.backendFailure("Direct UVC write not implemented for \(key.displayName).")
    }
}
