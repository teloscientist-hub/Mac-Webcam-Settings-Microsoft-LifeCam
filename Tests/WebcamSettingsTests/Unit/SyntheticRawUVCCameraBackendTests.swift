import Testing
@testable import WebcamSettings

@Test
func syntheticRawBackendReturnsMappedCapabilitiesForLifeCamCandidate() async throws {
    let backend = SyntheticRawUVCCameraBackend()

    let capabilities = try await backend.fetchCapabilities(for: makeSyntheticRawDevice())

    #expect(capabilities.contains(where: { $0.key == .brightness && $0.isSupported }))
    #expect(capabilities.contains(where: { $0.key == .pan && $0.isSupported }))
    #expect(capabilities.contains(where: { $0.key == .tilt && $0.isSupported }))
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
