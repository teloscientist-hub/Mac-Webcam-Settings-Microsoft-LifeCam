import Foundation

protocol RawUVCControlTransferExecuting: Sendable {
    func execute(transfer: RawUVCControlTransfer.Plan, payload: Data?) async throws -> Data
}

#if canImport(IOKit)
import IOKit
import IOKit.usb.IOUSBLib

struct IOKitRawUVCControlTransferExecutor: RawUVCControlTransferExecuting {
    private let serviceResolver: any RawUVCIOKitServiceResolving
    private let deviceInterfaceOpener: any RawUVCDeviceInterfaceOpening

    init(
        serviceResolver: any RawUVCIOKitServiceResolving = DefaultRawUVCIOKitServiceResolver(),
        deviceInterfaceOpener: any RawUVCDeviceInterfaceOpening = DefaultRawUVCDeviceInterfaceOpener()
    ) {
        self.serviceResolver = serviceResolver
        self.deviceInterfaceOpener = deviceInterfaceOpener
    }

    func execute(transfer: RawUVCControlTransfer.Plan, payload: Data?) async throws -> Data {
        let resolvedService = try serviceResolver.resolveService(for: transfer.target)
        let interfacePlan = RawUVCDeviceInterfacePlanner.makePlan(
            target: transfer.target,
            resolvedService: resolvedService
        )
        let openedDevice = try deviceInterfaceOpener.open(plan: interfacePlan)
        let interfaceSummary = openedDevice.interfaces.map(\.summary).joined(separator: "; ")
        let renderedInterfaceSummary = interfaceSummary.isEmpty ? "none" : interfaceSummary
        let selectedControlInterface = openedDevice.controlInterface?.summary ?? "none"

        guard let controlInterface = openedDevice.controlInterface else {
            throw CameraControlError.backendFailure(
                "IOKit raw UVC executor resolved registry entry 0x\(String(format: "%016llX", resolvedService.registryEntryID)) for \(transfer.target.summary) and opened the USB device interface (\(openedDevice.configurationCount) configurations; interfaces: \(renderedInterfaceSummary)), but no UVC control interface was found (interface plan: \(interfacePlan.summary); transfer: \(transfer.summary))."
            )
        }

        do {
            return try performControlRequest(
                transfer: transfer,
                payload: payload,
                controlInterface: controlInterface
            )
        } catch let error as CameraControlError {
            let message = "IOKit raw UVC request failed after opening device/interface for \(transfer.target.summary) (selected control interface: \(selectedControlInterface); interface plan: \(interfacePlan.summary); transfer: \(transfer.summary)): \(error.localizedDescription)"
            throw CameraControlError.backendFailure(message)
        } catch {
            let message = "IOKit raw UVC request failed after opening device/interface for \(transfer.target.summary) (selected control interface: \(selectedControlInterface); interface plan: \(interfacePlan.summary); transfer: \(transfer.summary)): \(error.localizedDescription)"
            throw CameraControlError.backendFailure(message)
        }
    }

    private func performControlRequest(
        transfer: RawUVCControlTransfer.Plan,
        payload: Data?,
        controlInterface: RawUVCEnumeratedInterface
    ) throws -> Data {
        guard let matching = IORegistryEntryIDMatching(controlInterface.registryEntryID) else {
            throw CameraControlError.backendFailure(
                "Failed to build an IOKit match dictionary for control interface registry entry 0x\(String(format: "%016llX", controlInterface.registryEntryID))."
            )
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            throw CameraControlError.backendFailure(
                "Could not reacquire the selected control interface service for registry entry 0x\(String(format: "%016llX", controlInterface.registryEntryID))."
            )
        }
        defer { IOObjectRelease(service) }

        var score: Int32 = 0
        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        let pluginResult = IOCreatePlugInInterfaceForService(
            service,
            makeExecutorUSBInterfaceUserClientTypeID(),
            makeExecutorIOCFPlugInInterfaceID(),
            &plugin,
            &score
        )

        guard pluginResult == kIOReturnSuccess, let plugin else {
            throw CameraControlError.backendFailure(
                "IOCreatePlugInInterfaceForService failed for control interface registry entry 0x\(String(format: "%016llX", controlInterface.registryEntryID)) with result 0x\(String(format: "%08X", pluginResult))."
            )
        }
        defer {
            _ = plugin.pointee?.pointee.Release(plugin)
        }

        var interfacePointer: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface942>?>?
        let queryResult: HRESULT = withUnsafeMutablePointer(to: &interfacePointer) { pointer in
            pointer.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { rebounded in
                plugin.pointee?.pointee.QueryInterface(
                    plugin,
                    CFUUIDGetUUIDBytes(makeExecutorUSBInterfaceInterfaceID942()),
                    rebounded
                ) ?? EINVAL
            }
        }

        guard queryResult == S_OK, let interfacePointer, let interface = interfacePointer.pointee else {
            throw CameraControlError.backendFailure(
                "QueryInterface for IOUSBInterfaceInterface942 failed with result 0x\(String(format: "%08X", queryResult))."
            )
        }
        defer {
            _ = interface.pointee.Release(interfacePointer)
        }

        let openResult = interface.pointee.USBInterfaceOpen(interfacePointer)
        guard openResult == kIOReturnSuccess else {
            throw mapIOReturn(
                openResult,
                context: "USBInterfaceOpen failed for interface \(controlInterface.summary)"
            )
        }
        defer {
            _ = interface.pointee.USBInterfaceClose(interfacePointer)
        }

        var mutablePayload = payload ?? Data(count: transfer.expectedLength)
        let effectiveIndex = transfer.index(forControlInterfaceNumber: controlInterface.interfaceNumber)
        let payloadLength = UInt16(mutablePayload.count)

        let result: IOReturn = mutablePayload.withUnsafeMutableBytes { buffer in
            var request = IOUSBDevRequest(
                bmRequestType: transfer.requestType,
                bRequest: transfer.request,
                wValue: transfer.value,
                wIndex: effectiveIndex,
                wLength: payloadLength,
                pData: buffer.baseAddress,
                wLenDone: 0
            )

            return interface.pointee.ControlRequest(interfacePointer, 0, &request)
        }

        guard result == kIOReturnSuccess else {
            throw mapIOReturn(
                result,
                context: "ControlRequest failed for interface \(controlInterface.summary) with effective index 0x\(String(format: "%04X", effectiveIndex))"
            )
        }

        switch transfer.direction {
        case .deviceToHost:
            return mutablePayload
        case .hostToDevice:
            return Data()
        }
    }

    private func mapIOReturn(_ result: IOReturn, context: String) -> CameraControlError {
        switch result {
        case kIOReturnNoDevice:
            return .deviceNotConnected
        case kIOReturnNotOpen, kIOReturnExclusiveAccess:
            return .deviceBusy
        case kIOReturnTimeout:
            return .timedOut
        default:
            return .backendFailure("\(context) with result 0x\(String(format: "%08X", result)).")
        }
    }
}

private func makeExecutorUSBInterfaceUserClientTypeID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x2d, 0x97, 0x86, 0xc6, 0x9e, 0xf3, 0x11, 0xD4,
        0xad, 0x51, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    )
}

private func makeExecutorIOCFPlugInInterfaceID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
        0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F
    )
}

private func makeExecutorUSBInterfaceInterfaceID942() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        kCFAllocatorSystemDefault,
        0x87, 0x52, 0x66, 0x3B, 0xC0, 0x7B, 0x4B, 0xAE,
        0x95, 0x84, 0x22, 0x03, 0x2F, 0xAB, 0x9C, 0x5A
    )
}
#endif

struct UnavailableRawUVCControlTransferExecutor: RawUVCControlTransferExecuting {
    func execute(transfer: RawUVCControlTransfer.Plan, payload: Data?) async throws -> Data {
        _ = payload
        throw CameraControlError.backendFailure(
            "Direct raw UVC control transfer is not implemented (\(transfer.summary))."
        )
    }
}
