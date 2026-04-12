import Testing
@testable import WebcamSettings

@Test
func deviceInterfacePlanUsesExpectedUSBUserClientIdentifiers() {
    let target = RawUVCTransportTarget(
        manufacturer: "Microsoft",
        productName: "Microsoft LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123",
        avFoundationUniqueID: "avf-plan-1",
        backendIdentifier: "backend-plan-1",
        registryEntryID: 0x1234,
        serviceClassName: "IOUSBHostDevice",
        matchQuality: .exactSerial
    )
    let resolvedService = RawUVCResolvedIOKitService(
        registryEntryID: 0x1234,
        serviceClassName: "IOUSBHostDevice"
    )

    let plan = RawUVCDeviceInterfacePlanner.makePlan(
        target: target,
        resolvedService: resolvedService
    )

    #expect(plan.uuidPlan.pluginType == "kIOUSBDeviceUserClientTypeID")
    #expect(plan.uuidPlan.pluginInterface == "kIOCFPlugInInterfaceID")
    #expect(plan.uuidPlan.deviceInterface == "kIOUSBDeviceInterfaceID942")
    #expect(plan.preferredOpenMode == .seizeIfNeeded)
    #expect(plan.shouldEnumerateInterfaces == true)
}
