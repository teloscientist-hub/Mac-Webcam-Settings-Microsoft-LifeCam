import Foundation
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
func rawBindingsBuildSetCurrentRequestPlanForMappedControl() {
    let plan = RawUVCBindings.requestPlan(
        for: .brightness,
        device: makeRawLifeCam(),
        operation: .setCurrent
    )

    #expect(plan?.entity == .processingUnit)
    #expect(plan?.selector == 0x02)
    #expect(plan?.unitID == 0x02)
    #expect(plan?.expectedLength == 2)
    #expect(plan?.operation == .setCurrent)
}

@Test
func rawBindingsBuildGetCurrentRequestPlanForMappedControl() {
    let plan = RawUVCBindings.requestPlan(
        for: .focus,
        device: makeRawLifeCam(),
        operation: .getCurrent
    )

    #expect(plan?.entity == .cameraTerminal)
    #expect(plan?.selector == 0x06)
    #expect(plan?.unitID == 0x01)
    #expect(plan?.expectedLength == 2)
    #expect(plan?.operation == .getCurrent)
}

@Test
func rawBindingsEncodeBrightnessPayloadAsLittleEndian() throws {
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .brightness, device: makeRawLifeCam(), operation: .setCurrent)
    )

    let payload = try RawUVCBindings.encodePayload(for: .int(133), plan: plan)

    #expect(payload == Data([0x85, 0x00]))
}

@Test
func rawBindingsDecodeBrightnessPayloadAsLittleEndian() throws {
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .brightness, device: makeRawLifeCam(), operation: .getCurrent)
    )

    let value = try RawUVCBindings.decodePayload(Data([0x85, 0x00]), plan: plan)

    #expect(value == .int(133))
}

@Test
func rawBindingsEncodePowerLineFrequencyEnumPayload() throws {
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .powerLineFrequency, device: makeRawLifeCam(), operation: .setCurrent)
    )

    let payload = try RawUVCBindings.encodePayload(for: .enumCase("60hz"), plan: plan)

    #expect(payload == Data([0x02]))
}

@Test
func rawBindingsDecodeBooleanPayload() throws {
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .focusAuto, device: makeRawLifeCam(), operation: .getCurrent)
    )

    let value = try RawUVCBindings.decodePayload(Data([0x01]), plan: plan)

    #expect(value == .bool(true))
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
