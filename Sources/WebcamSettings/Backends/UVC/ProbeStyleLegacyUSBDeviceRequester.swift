import Foundation

#if canImport(IOKit)
import IOKit
import IOKit.usb.IOUSBLib

struct ProbeStyleLegacyUSBDeviceRequestResult: Sendable, Equatable {
    let status: IOReturn
    let bytesTransferred: UInt32
}

struct ProbeStyleLegacyUSBDeviceRequester {
    func sendRequest(
        vendorID: UInt16,
        productID: UInt16,
        seize: Bool,
        requestType: UInt8,
        request: UInt8,
        value: UInt16,
        index: UInt16,
        payload: inout Data,
        noDataTimeout: UInt32,
        completionTimeout: UInt32
    ) -> ProbeStyleLegacyUSBDeviceRequestResult {
        do {
            let matches = try findTargetDevices(vendorID: vendorID, productID: productID)
            var lastStatus: IOReturn = kIOReturnNoDevice

            for match in matches {
                do {
                    let result = try attemptRequest(
                        match: match,
                        seize: seize,
                        requestType: requestType,
                        request: request,
                        value: value,
                        index: index,
                        payload: &payload,
                        noDataTimeout: noDataTimeout,
                        completionTimeout: completionTimeout
                    )
                    if result.status == kIOReturnSuccess {
                        return result
                    }
                    lastStatus = result.status
                } catch let error as ProbeStyleLegacyUSBDeviceRequestError {
                    lastStatus = error.status
                } catch {
                    lastStatus = kIOReturnError
                }
            }

            return ProbeStyleLegacyUSBDeviceRequestResult(status: lastStatus, bytesTransferred: 0)
        } catch let error as ProbeStyleLegacyUSBDeviceRequestError {
            return ProbeStyleLegacyUSBDeviceRequestResult(status: error.status, bytesTransferred: 0)
        } catch {
            return ProbeStyleLegacyUSBDeviceRequestResult(status: kIOReturnError, bytesTransferred: 0)
        }
    }

    private func findTargetDevices(vendorID: UInt16, productID: UInt16) throws -> [USBMatch] {
        let classNames = ["IOUSBDevice", "IOUSBHostDevice"]
        var matches: [USBMatch] = []

        for className in classNames {
            guard let dictionary = IOServiceMatching(className) else { continue }
            var iterator: io_iterator_t = 0
            let result = IOServiceGetMatchingServices(kIOMainPortDefault, dictionary, &iterator)
            guard result == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }

            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }

                let serviceVendorID = copyIntProperty("idVendor", service: service)
                let serviceProductID = copyIntProperty("idProduct", service: service)
                guard serviceVendorID == Int(vendorID), serviceProductID == Int(productID) else {
                    continue
                }

                var registryEntryID: UInt64 = 0
                guard IORegistryEntryGetRegistryEntryID(service, &registryEntryID) == KERN_SUCCESS else {
                    continue
                }

                matches.append(
                    USBMatch(
                        registryEntryID: registryEntryID,
                        serviceClassName: className
                    )
                )
            }
        }

        guard matches.isEmpty == false else {
            throw ProbeStyleLegacyUSBDeviceRequestError(status: kIOReturnNoDevice)
        }

        return matches
    }

    private func openDeviceInterface(
        registryEntryID: UInt64
    ) throws -> (pointer: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>, interface: UnsafeMutablePointer<IOUSBDeviceInterface942>) {
        guard let matching = IORegistryEntryIDMatching(registryEntryID) else {
            throw ProbeStyleLegacyUSBDeviceRequestError(status: kIOReturnBadArgument)
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            throw ProbeStyleLegacyUSBDeviceRequestError(status: kIOReturnNoDevice)
        }
        defer { IOObjectRelease(service) }

        var score: Int32 = 0
        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        let pluginResult = IOCreatePlugInInterfaceForService(
            service,
            makeProbeUSBDeviceUserClientTypeID(),
            makeProbeIOCFPlugInInterfaceID(),
            &plugin,
            &score
        )
        guard pluginResult == kIOReturnSuccess, let plugin else {
            throw ProbeStyleLegacyUSBDeviceRequestError(status: pluginResult)
        }
        defer {
            _ = plugin.pointee?.pointee.Release(plugin)
        }

        var deviceInterfacePointer: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>?
        let queryResult: HRESULT = withUnsafeMutablePointer(to: &deviceInterfacePointer) { pointer in
            pointer.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { rebound in
                plugin.pointee?.pointee.QueryInterface(
                    plugin,
                    CFUUIDGetUUIDBytes(makeProbeUSBDeviceInterfaceID942()),
                    rebound
                ) ?? EINVAL
            }
        }

        guard queryResult == S_OK,
              let deviceInterfacePointer,
              let deviceInterface = deviceInterfacePointer.pointee
        else {
            throw ProbeStyleLegacyUSBDeviceRequestError(status: IOReturn(queryResult))
        }

        return (deviceInterfacePointer, deviceInterface)
    }

    private func attemptRequest(
        match: USBMatch,
        seize: Bool,
        requestType: UInt8,
        request: UInt8,
        value: UInt16,
        index: UInt16,
        payload: inout Data,
        noDataTimeout: UInt32,
        completionTimeout: UInt32
    ) throws -> ProbeStyleLegacyUSBDeviceRequestResult {
        let deviceInterface = try openDeviceInterface(registryEntryID: match.registryEntryID)
        defer {
            _ = deviceInterface.interface.pointee.Release(deviceInterface.pointer)
        }

        let openResult = seize
            ? deviceInterface.interface.pointee.USBDeviceOpenSeize(deviceInterface.pointer)
            : deviceInterface.interface.pointee.USBDeviceOpen(deviceInterface.pointer)
        guard openResult == kIOReturnSuccess else {
            return ProbeStyleLegacyUSBDeviceRequestResult(status: openResult, bytesTransferred: 0)
        }
        defer {
            _ = deviceInterface.interface.pointee.USBDeviceClose(deviceInterface.pointer)
        }

        var bytesTransferred: UInt32 = 0
        let payloadLength = UInt16(payload.count)
        let result: IOReturn = payload.withUnsafeMutableBytes { buffer in
            var usbRequest = IOUSBDevRequestTO(
                bmRequestType: requestType,
                bRequest: request,
                wValue: value,
                wIndex: index,
                wLength: payloadLength,
                pData: buffer.baseAddress,
                wLenDone: 0,
                noDataTimeout: noDataTimeout,
                completionTimeout: completionTimeout
            )
            let requestResult = deviceInterface.pointer.pointee?.pointee.DeviceRequestTO(deviceInterface.pointer, &usbRequest) ?? kIOReturnError
            bytesTransferred = UInt32(usbRequest.wLenDone)
            return requestResult
        }

        return ProbeStyleLegacyUSBDeviceRequestResult(status: result, bytesTransferred: bytesTransferred)
    }

    private func copyIntProperty(_ key: String, service: io_service_t) -> Int? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        return (value as? NSNumber)?.intValue
    }
}

private struct USBMatch: Sendable, Equatable {
    let registryEntryID: UInt64
    let serviceClassName: String
}

private struct ProbeStyleLegacyUSBDeviceRequestError: Error {
    let status: IOReturn
}

private func makeProbeUSBDeviceUserClientTypeID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xD4,
        0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    )
}

private func makeProbeIOCFPlugInInterfaceID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
        0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F
    )
}

private func makeProbeUSBDeviceInterfaceID942() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        kCFAllocatorSystemDefault,
        0x56, 0xAD, 0x08, 0x9D, 0x87, 0x8D, 0x4B, 0xEA,
        0xA1, 0xF5, 0x2C, 0x8D, 0xC4, 0x3E, 0x8A, 0x98
    )
}
#endif
