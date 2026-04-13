import Testing
@testable import WebcamSettings

@Test
func backendRejectsManualFocusWhileAutofocusEnabled() async throws {
    let backend = InMemoryUVCCameraBackend()
    let device = makeBackendDevice()

    _ = try await backend.fetchCapabilities(for: device)
    try await backend.writeValue(.bool(true), for: .focusAuto, device: device)
    do {
        try await backend.writeValue(.int(20), for: .focus, device: device)
        Issue.record("Expected autofocus dependency to reject manual focus write")
    } catch let error as CameraControlError {
        #expect(error == .invalidValue(.focus))
    }
}

@Test
func backendAllowsManualFocusAfterDisablingAutofocus() async throws {
    let backend = InMemoryUVCCameraBackend()
    let device = makeBackendDevice()

    _ = try await backend.fetchCapabilities(for: device)
    try await backend.writeValue(.bool(false), for: .focusAuto, device: device)
    try await backend.writeValue(.int(20), for: .focus, device: device)

    let values = try await backend.readCurrentValues(for: device)
    #expect(values[.focusAuto] == .bool(false))
    #expect(values[.focus] == .int(20))
}

@Test
func backendMarksAdvancedControlsUnsupportedForGenericDevices() async throws {
    let backend = InMemoryUVCCameraBackend()
    let genericDevice = CameraDeviceDescriptor(
        id: "generic-1",
        name: "Generic USB Camera",
        manufacturer: nil,
        model: nil,
        vendorID: nil,
        productID: nil,
        serialNumber: nil,
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "generic-avf",
        backendIdentifier: "generic-backend"
    )

    let capabilities = try await backend.fetchCapabilities(for: genericDevice)
    let panCapability = capabilities.first(where: { $0.key == .pan })

    #expect(panCapability?.isSupported == false)
}

@Test
func lifeCamProfileUsesRicherWhiteBalanceRangeAndLeavesPanUnsupported() async throws {
    let backend = InMemoryUVCCameraBackend()
    let capabilities = try await backend.fetchCapabilities(for: makeBackendDevice())

    let whiteBalance = capabilities.first(where: { $0.key == .whiteBalanceTemperature })
    let pan = capabilities.first(where: { $0.key == .pan })

    #expect(whiteBalance?.minValue == .int(2500))
    #expect(whiteBalance?.maxValue == .int(10_000))
    #expect(pan?.isSupported == false)
}

@Test
func lifeCamVendorProductFingerprintSelectsLifeCamBackendProfile() async throws {
    let backend = InMemoryUVCCameraBackend()
    let disguisedLifeCam = CameraDeviceDescriptor(
        id: "lifecam-2",
        name: "USB Camera",
        manufacturer: "Microsoft",
        model: "UVC Camera",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "DEF456",
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "lifecam-avf-2",
        backendIdentifier: "lifecam-backend-2"
    )

    let capabilities = try await backend.fetchCapabilities(for: disguisedLifeCam)
    let pan = capabilities.first(where: { $0.key == .pan })
    let zoom = capabilities.first(where: { $0.key == .zoom })

    #expect(pan?.isSupported == false)
    #expect(zoom?.isSupported == true)
    #expect(zoom?.maxValue == .int(317))
}

private func makeBackendDevice() -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "lifecam-1",
        name: "Microsoft LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123",
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "lifecam-avf",
        backendIdentifier: "lifecam-backend"
    )
}
