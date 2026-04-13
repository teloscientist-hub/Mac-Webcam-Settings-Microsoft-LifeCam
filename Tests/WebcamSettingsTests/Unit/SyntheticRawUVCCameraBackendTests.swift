import Foundation
import Testing
@testable import WebcamSettings

@Test
func syntheticRawBackendReturnsMappedCapabilitiesForLifeCamCandidate() async throws {
    let backend = SyntheticRawUVCCameraBackend()

    let capabilities = try await backend.fetchCapabilities(for: makeSyntheticRawDevice())

    #expect(capabilities.contains(where: { $0.key == .brightness && $0.isSupported && $0.source == .rawCatalog }))
    #expect(capabilities.contains(where: { $0.key == .pan && $0.isSupported && $0.source == .rawCatalog }))
    #expect(capabilities.contains(where: { $0.key == .tilt && $0.isSupported && $0.source == .rawCatalog }))
}

@Test
func syntheticRawBackendRejectsNonRawCandidateDevices() async {
    let backend = SyntheticRawUVCCameraBackend()
    let nonUSBDevice = CameraDeviceDescriptor(
        id: "builtin-1",
        name: "Built-in Camera",
        manufacturer: "Apple",
        model: "FaceTime HD Camera",
        vendorID: nil,
        productID: nil,
        serialNumber: nil,
        transportType: .builtIn,
        isConnected: true,
        avFoundationUniqueID: "avf-builtin-1",
        backendIdentifier: "backend-builtin-1"
    )

    do {
        _ = try await backend.fetchCapabilities(for: nonUSBDevice)
        Issue.record("Expected non-USB device to be rejected by synthetic raw backend")
    } catch let error as CameraControlError {
        #expect(error == .backendFailure("Device is not a raw UVC candidate."))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test
func syntheticRawBackendPreservesSuccessfulPartialReads() async throws {
    let transport = MockRawTransport()
    let backend = SyntheticRawUVCCameraBackend(transport: transport)
    let device = makeSyntheticRawDevice()

    await transport.setReadResponse(.int(120), for: .brightness, device: device)
    await transport.setReadFailure(.deviceBusy, for: .contrast, device: device)

    let values = try await backend.readCurrentValues(for: device)

    #expect(values[.brightness] == .int(120))
    #expect(values[.contrast] == .int(1))
}

@Test
func syntheticRawBackendUsesCachedWriteValueWhenSubsequentReadFails() async throws {
    let transport = MockRawTransport()
    let backend = SyntheticRawUVCCameraBackend(transport: transport)
    let device = makeSyntheticRawDevice()

    try await backend.writeValue(.bool(false), for: .whiteBalanceAuto, device: device)
    await transport.setReadFailure(.deviceBusy, for: .whiteBalanceAuto, device: device)
    await transport.setReadResponse(.int(4100), for: .whiteBalanceTemperature, device: device)

    let values = try await backend.readCurrentValues(for: device)

    #expect(values[.whiteBalanceAuto] == .bool(false))
    #expect(values[.whiteBalanceTemperature] == .int(4100))
}

private func makeSyntheticRawDevice() -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "synthetic-raw-1",
        name: "Microsoft LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123",
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-synthetic-1",
        backendIdentifier: "backend-synthetic-1"
    )
}

private actor MockRawTransport: RawUVCTransporting {
    private var responses: [String: Result<Data, CameraControlError>] = [:]

    func setReadResponse(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) {
        guard let plan = RawUVCBindings.requestPlan(for: key, device: device, operation: .getCurrent),
              let payload = try? RawUVCBindings.encodePayload(for: value, plan: plan)
        else {
            return
        }
        responses[storageKey(for: plan, device: device)] = .success(payload)
    }

    func setReadFailure(_ error: CameraControlError, for key: CameraControlKey, device: CameraDeviceDescriptor) {
        guard let plan = RawUVCBindings.requestPlan(for: key, device: device, operation: .getCurrent) else {
            return
        }
        responses[storageKey(for: plan, device: device)] = .failure(error)
    }

    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        let key = storageKey(for: plan, device: device)
        if let configured = responses[key] {
            switch configured {
            case let .success(data):
                return data
            case let .failure(error):
                throw error
            }
        }

        switch plan.operation {
        case .getCurrent:
            let fallbackValue = BackendCapabilityCatalog
                .capabilities(for: device, supportedKeys: Set(RawUVCBindings.mappedControls(for: device).map(\.key)))
                .first(where: { $0.key == plan.key })?
                .currentValue ?? .int(0)
            return try RawUVCBindings.encodePayload(for: fallbackValue, plan: plan)
        case .setCurrent:
            return Data()
        }
    }

    private func storageKey(for plan: RawUVCBindings.RequestPlan, device: CameraDeviceDescriptor) -> String {
        "\(device.id)|\(plan.operation.rawValue)|\(plan.key.rawValue)"
    }
}
