import Testing
@testable import WebcamSettings

@Test
func rawBindingsExposeLifeCamMappedControls() {
    let descriptors = RawUVCBindings.mappedControls(for: makeRawLifeCam())

    #expect(descriptors.count >= 10)
    #expect(descriptors.contains(where: { $0.key == .brightness && $0.entity == .processingUnit }))
    #expect(descriptors.contains(where: { $0.key == .focus && $0.entity == .cameraTerminal }))
}

@Test
func rawBindingsExposeSpecificDescriptorForLifeCamControl() {
    let descriptor = RawUVCBindings.descriptor(for: .whiteBalanceTemperature, device: makeRawLifeCam())

    #expect(descriptor?.entity == .processingUnit)
    #expect(descriptor?.selector == 0x0A)
    #expect(descriptor?.unitID == 0x02)
}

@Test
func rawBindingsTreatUSBDeviceAsRawCandidateEvenBeforeImplementation() {
    let device = makeRawLifeCam()

    #expect(RawUVCBindings.canAttemptDirectAccess(for: device) == true)
    #expect(RawUVCBindings.backendSummary(for: device).contains("Raw UVC candidate"))
    #expect(RawUVCBindings.mappingSummary(for: device).contains("mapped controls"))
    #expect(RawUVCBindings.pipelineSummary(for: device).contains("Capabilities from raw mapping catalog"))
}

private func makeRawLifeCam() -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "raw-cam-1",
        name: "Microsoft LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123",
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-raw-1",
        backendIdentifier: "backend-raw-1"
    )
}
