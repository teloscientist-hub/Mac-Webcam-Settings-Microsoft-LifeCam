import Foundation

#if canImport(IOKit)
struct LegacyDirectUVCControlRequester {
    private let legacyDeviceRequester = ProbeStyleLegacyUSBDeviceRequester()
    private let noDataTimeout: UInt32 = 500
    private let completionTimeout: UInt32 = 1000

    func writeAndReadBack(
        value: CameraControlValue,
        key: CameraControlKey,
        device: CameraDeviceDescriptor,
        seize: Bool = true
    ) throws -> CameraControlValue {
        guard let vendorID = device.vendorID.map(UInt16.init),
              let productID = device.productID.map(UInt16.init),
              let setPlan = RawUVCBindings.requestPlan(for: key, device: device, operation: .setCurrent),
              let getPlan = RawUVCBindings.requestPlan(for: key, device: device, operation: .getCurrent)
        else {
            throw CameraControlError.controlUnsupported(key)
        }

        var writePayload = try RawUVCBindings.encodePayload(for: value, plan: setPlan)
        let setResult = legacyDeviceRequester.sendRequest(
            vendorID: vendorID,
            productID: productID,
            seize: seize,
            requestType: 0x21,
            request: 0x01,
            value: UInt16(setPlan.selector) << 8,
            index: UInt16(setPlan.unitID) << 8,
            payload: &writePayload,
            noDataTimeout: noDataTimeout,
            completionTimeout: completionTimeout
        )

        guard setResult.status == kIOReturnSuccess else {
            throw mapLegacyIOReturn(
                IOReturn(setResult.status),
                context: "Direct legacy UVC write failed for \(key.displayName)"
            )
        }

        var readPayload = Data(count: getPlan.expectedLength)
        let getResult = legacyDeviceRequester.sendRequest(
            vendorID: vendorID,
            productID: productID,
            seize: seize,
            requestType: 0xA1,
            request: 0x81,
            value: UInt16(getPlan.selector) << 8,
            index: UInt16(getPlan.unitID) << 8,
            payload: &readPayload,
            noDataTimeout: noDataTimeout,
            completionTimeout: completionTimeout
        )

        guard getResult.status == kIOReturnSuccess else {
            throw mapLegacyIOReturn(
                IOReturn(getResult.status),
                context: "Direct legacy UVC readback failed for \(key.displayName)"
            )
        }

        return try RawUVCBindings.decodePayload(readPayload, plan: getPlan)
    }

    private func mapLegacyIOReturn(_ result: IOReturn, context: String) -> CameraControlError {
        switch result {
        case kIOReturnNotOpen:
            return .deviceNotConnected
        case kIOReturnExclusiveAccess, kIOReturnBusy:
            return .deviceBusy
        case kIOReturnNoDevice:
            return .deviceNotConnected
        case kIOReturnNoResources:
            return .backendFailure("\(context): device resources unavailable")
        case kIOReturnTimeout:
            return .timedOut
        default:
            return .backendFailure("\(context): 0x\(String(format: "%08X", result))")
        }
    }
}
#endif
