import Testing
@testable import WebcamSettings

@Test
func deviceMatchScorePrefersExactIdentifierMatches() {
    let device = CameraDeviceDescriptor(
        id: "cam-1",
        name: "Microsoft LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123",
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-1",
        backendIdentifier: "backend-1"
    )
    let exact = ProfileDeviceMatch(
        deviceName: "Microsoft LifeCam Studio",
        deviceIdentifier: "backend-1",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123"
    )
    let partial = ProfileDeviceMatch(
        deviceName: "Microsoft LifeCam Studio",
        deviceIdentifier: nil,
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: nil
    )

    #expect(device.matchScore(for: exact) > device.matchScore(for: partial))
}

@Test
func profileDeviceMatchReturnsFalseForUnrelatedDevice() {
    let device = CameraDeviceDescriptor(
        id: "cam-2",
        name: "Built-in Camera",
        manufacturer: "Apple",
        model: "FaceTime HD Camera",
        vendorID: nil,
        productID: nil,
        serialNumber: nil,
        transportType: .builtIn,
        isConnected: true,
        avFoundationUniqueID: "avf-2",
        backendIdentifier: "backend-2"
    )
    let match = ProfileDeviceMatch(
        deviceName: "LifeCam Studio",
        deviceIdentifier: "backend-1",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: nil
    )

    #expect(match.matches(device) == false)
}
