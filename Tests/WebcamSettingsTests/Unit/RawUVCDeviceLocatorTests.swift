import Testing
@testable import WebcamSettings

@Test
func transportTargetPrefersSerialMatchWhenAvailable() {
    let device = makeLocatorDevice(
        serialNumber: nil,
        vendorID: 0x045E,
        productID: 0x0772
    )
    let resolution = RawUVCDeviceResolution(
        manufacturer: "Microsoft",
        productName: "Microsoft LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123",
        registryEntryID: 0x1234,
        serviceClassName: "IOUSBHostDevice"
    )

    let target = RawUVCDeviceLocatorSupport.makeTransportTarget(for: device, resolution: resolution)

    #expect(target?.matchQuality == .exactSerial)
    #expect(target?.summary.contains("serial ABC123") == true)
    #expect(target?.summary.contains("registry 0x0000000000001234") == true)
    #expect(target?.summary.contains("class IOUSBHostDevice") == true)
}

@Test
func transportTargetFallsBackToVendorProductMatch() {
    let device = makeLocatorDevice(
        serialNumber: nil,
        vendorID: 0x045E,
        productID: 0x0772
    )

    let target = RawUVCDeviceLocatorSupport.makeTransportTarget(for: device, resolution: nil)

    #expect(target?.matchQuality == .vendorProduct)
    #expect(target?.summary.contains("VID:PID 045E:0772") == true)
}

@Test
func transportTargetFallsBackToNameOnlyWhenUSBIdsAreUnavailable() {
    let device = makeLocatorDevice(
        serialNumber: nil,
        vendorID: nil,
        productID: nil
    )

    let target = RawUVCDeviceLocatorSupport.makeTransportTarget(for: device, resolution: nil)

    #expect(target?.matchQuality == .nameOnly)
    #expect(target?.summary.contains("LifeCam Studio") == true)
}

private func makeLocatorDevice(
    serialNumber: String?,
    vendorID: Int?,
    productID: Int?
) -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "locator-cam-1",
        name: "Microsoft LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: vendorID,
        productID: productID,
        serialNumber: serialNumber,
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-locator-1",
        backendIdentifier: "backend-locator-1"
    )
}
