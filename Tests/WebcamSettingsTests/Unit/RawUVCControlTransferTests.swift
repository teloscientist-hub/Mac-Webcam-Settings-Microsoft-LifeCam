import Testing
@testable import WebcamSettings

@Test
func getCurrentTransferPlanUsesDeviceToHostUVCRequestShape() throws {
    let requestPlan = try #require(
        RawUVCBindings.requestPlan(for: .brightness, device: makeTransferDevice(), operation: .getCurrent)
    )
    let target = try #require(
        RawUVCDeviceLocatorSupport.makeTransportTarget(for: makeTransferDevice(), resolution: nil)
    )

    let transfer = RawUVCControlTransfer.plan(for: requestPlan, target: target)

    #expect(transfer.direction == .deviceToHost)
    #expect(transfer.request == 0x81)
    #expect(transfer.requestType == 0xA1)
    #expect(transfer.value == 0x0200)
    #expect(transfer.index == 0x0004)
    #expect(transfer.index(forControlInterfaceNumber: 3) == 0x0403)
    #expect(transfer.expectedLength == 2)
}

@Test
func setCurrentTransferPlanUsesHostToDeviceUVCRequestShape() throws {
    let requestPlan = try #require(
        RawUVCBindings.requestPlan(for: .focusAuto, device: makeTransferDevice(), operation: .setCurrent)
    )
    let target = try #require(
        RawUVCDeviceLocatorSupport.makeTransportTarget(for: makeTransferDevice(), resolution: nil)
    )

    let transfer = RawUVCControlTransfer.plan(for: requestPlan, target: target)

    #expect(transfer.direction == .hostToDevice)
    #expect(transfer.request == 0x01)
    #expect(transfer.requestType == 0x21)
    #expect(transfer.value == 0x0800)
    #expect(transfer.index == 0x0001)
    #expect(transfer.index(forControlInterfaceNumber: 4) == 0x0104)
    #expect(transfer.expectedLength == 1)
}

private func makeTransferDevice() -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "transfer-cam-1",
        name: "Microsoft LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: nil,
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-transfer-1",
        backendIdentifier: "backend-transfer-1"
    )
}
