import Foundation

#if canImport(IOKit)
import IOKit
import IOKit.usb.IOUSBLib

struct RawUVCEnumeratedInterface: Sendable, Equatable {
    let registryEntryID: UInt64
    let interfaceNumber: UInt8
    let alternateSetting: UInt8
    let interfaceClass: UInt8
    let interfaceSubClass: UInt8
    let interfaceProtocol: UInt8
    let endpointCount: UInt8

    var summary: String {
        "if=\(interfaceNumber) alt=\(alternateSetting) class=0x\(String(format: "%02X", interfaceClass)) subclass=0x\(String(format: "%02X", interfaceSubClass)) protocol=0x\(String(format: "%02X", interfaceProtocol)) endpoints=\(endpointCount)"
    }
}

protocol RawUVCInterfaceEnumerating: Sendable {
    func enumerate(deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>) throws -> [RawUVCEnumeratedInterface]
}

struct DefaultRawUVCInterfaceEnumerator: RawUVCInterfaceEnumerating {
    func enumerate(deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>) throws -> [RawUVCEnumeratedInterface] {
        guard let device = deviceInterface.pointee else {
            throw CameraControlError.backendFailure("Device interface was unexpectedly nil during interface enumeration.")
        }

        var request = IOUSBFindInterfaceRequest(
            bInterfaceClass: findInterfaceDontCare,
            bInterfaceSubClass: findInterfaceDontCare,
            bInterfaceProtocol: findInterfaceDontCare,
            bAlternateSetting: findInterfaceDontCare
        )

        var iterator: io_iterator_t = 0
        let createResult = device.pointee.CreateInterfaceIterator(deviceInterface, &request, &iterator)
        guard createResult == kIOReturnSuccess else {
            throw CameraControlError.backendFailure(
                "CreateInterfaceIterator failed with result 0x\(String(format: "%08X", createResult))."
            )
        }

        defer { IOObjectRelease(iterator) }

        var interfaces: [RawUVCEnumeratedInterface] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let enumerated = try openInterface(service: service) {
                interfaces.append(enumerated)
            }
        }

        return interfaces
    }

    private func openInterface(service: io_service_t) throws -> RawUVCEnumeratedInterface? {
        var registryEntryID: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(service, &registryEntryID) == kIOReturnSuccess else {
            return nil
        }

        var score: Int32 = 0
        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        let pluginResult = IOCreatePlugInInterfaceForService(
            service,
            makeUSBInterfaceUserClientTypeID(),
            makeInterfaceEnumeratorIOCFPlugInInterfaceID(),
            &plugin,
            &score
        )

        guard pluginResult == kIOReturnSuccess, let plugin else {
            return nil
        }
        defer {
            _ = plugin.pointee?.pointee.Release(plugin)
        }

        var interfaceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface942>?>?
        let queryResult: HRESULT = withUnsafeMutablePointer(to: &interfaceInterface) { pointer in
            pointer.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { rebounded in
                plugin.pointee?.pointee.QueryInterface(
                    plugin,
                    CFUUIDGetUUIDBytes(makeUSBInterfaceInterfaceID942()),
                    rebounded
                ) ?? EINVAL
            }
        }

        guard queryResult == S_OK, let interfaceInterface, let interface = interfaceInterface.pointee else {
            return nil
        }
        defer {
            _ = interface.pointee.Release(interfaceInterface)
        }

        var interfaceClass: UInt8 = 0
        var interfaceSubClass: UInt8 = 0
        var interfaceProtocol: UInt8 = 0
        var interfaceNumber: UInt8 = 0
        var alternateSetting: UInt8 = 0
        var endpointCount: UInt8 = 0

        guard interface.pointee.GetInterfaceClass(interfaceInterface, &interfaceClass) == kIOReturnSuccess,
              interface.pointee.GetInterfaceSubClass(interfaceInterface, &interfaceSubClass) == kIOReturnSuccess,
              interface.pointee.GetInterfaceProtocol(interfaceInterface, &interfaceProtocol) == kIOReturnSuccess,
              interface.pointee.GetInterfaceNumber(interfaceInterface, &interfaceNumber) == kIOReturnSuccess,
              interface.pointee.GetAlternateSetting(interfaceInterface, &alternateSetting) == kIOReturnSuccess,
              interface.pointee.GetNumEndpoints(interfaceInterface, &endpointCount) == kIOReturnSuccess else {
            return nil
        }

        return RawUVCEnumeratedInterface(
            registryEntryID: registryEntryID,
            interfaceNumber: interfaceNumber,
            alternateSetting: alternateSetting,
            interfaceClass: interfaceClass,
            interfaceSubClass: interfaceSubClass,
            interfaceProtocol: interfaceProtocol,
            endpointCount: endpointCount
        )
    }
}

private let findInterfaceDontCare: UInt16 = 0xFFFF

private func makeUSBInterfaceUserClientTypeID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x2d, 0x97, 0x86, 0xc6, 0x9e, 0xf3, 0x11, 0xD4,
        0xad, 0x51, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    )
}

private func makeInterfaceEnumeratorIOCFPlugInInterfaceID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
        0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F
    )
}

private func makeUSBInterfaceInterfaceID942() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        kCFAllocatorSystemDefault,
        0x87, 0x52, 0x66, 0x3B, 0xC0, 0x7B, 0x4B, 0xAE,
        0x95, 0x84, 0x22, 0x03, 0x2F, 0xAB, 0x9C, 0x5A
    )
}
#endif
