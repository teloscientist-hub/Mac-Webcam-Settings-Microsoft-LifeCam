import Testing
@testable import WebcamSettings

@Test
func startupProfileRequiresSomeDeviceMatch() {
    let matchingDevice = CameraDeviceDescriptor(
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
    let nonMatchingDevice = CameraDeviceDescriptor(
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
    let profileMatch = ProfileDeviceMatch(
        deviceName: "Microsoft LifeCam Studio",
        deviceIdentifier: "backend-1",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123"
    )

    #expect(matchingDevice.matchScore(for: profileMatch) > 0)
    #expect(nonMatchingDevice.matchScore(for: profileMatch) == 0)
}
