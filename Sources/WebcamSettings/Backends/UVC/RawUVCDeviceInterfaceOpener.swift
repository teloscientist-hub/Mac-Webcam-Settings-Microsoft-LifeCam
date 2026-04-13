import Foundation

#if canImport(IOKit)
import IOKit
import IOKit.usb.IOUSBLib

struct RawUVCOpenedDeviceInterface: Sendable, Equatable {
    let registryEntryID: UInt64
    let configurationCount: UInt8
    let deviceOpenResult: IOReturn?
    let interfaces: [RawUVCEnumeratedInterface]
    let controlInterface: RawUVCEnumeratedInterface?
}

protocol RawUVCDeviceInterfaceOpening: Sendable {
    func open(plan: RawUVCDeviceInterfacePlan) throws -> RawUVCOpenedDeviceInterface
}

struct DefaultRawUVCDeviceInterfaceOpener: RawUVCDeviceInterfaceOpening {
    private let interfaceEnumerator: any RawUVCInterfaceEnumerating

    init(interfaceEnumerator: any RawUVCInterfaceEnumerating = DefaultRawUVCInterfaceEnumerator()) {
        self.interfaceEnumerator = interfaceEnumerator
    }

    func open(plan: RawUVCDeviceInterfacePlan) throws -> RawUVCOpenedDeviceInterface {
        guard let resolvedService = plan.resolvedService else {
            throw CameraControlError.backendFailure(
                "Cannot open a USB device interface without a resolved IOKit service."
            )
        }

        guard let matching = IORegistryEntryIDMatching(resolvedService.registryEntryID) else {
            throw CameraControlError.backendFailure(
                "Failed to rebuild an IOKit match dictionary for registry entry 0x\(String(format: "%016llX", resolvedService.registryEntryID))."
            )
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            throw CameraControlError.backendFailure(
                "Could not reacquire IOKit service for registry entry 0x\(String(format: "%016llX", resolvedService.registryEntryID))."
            )
        }
        defer { IOObjectRelease(service) }

        var score: Int32 = 0
        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        let pluginResult = IOCreatePlugInInterfaceForService(
            service,
            makeUSBDeviceUserClientTypeID(),
            makeIOCFPlugInInterfaceID(),
            &plugin,
            &score
        )

        guard pluginResult == kIOReturnSuccess, let plugin else {
            throw CameraControlError.backendFailure(
                "IOCreatePlugInInterfaceForService failed for registry entry 0x\(String(format: "%016llX", resolvedService.registryEntryID)) with result 0x\(String(format: "%08X", pluginResult))."
            )
        }
        defer {
            _ = plugin.pointee?.pointee.Release(plugin)
        }

        var deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>?
        let queryResult: HRESULT = withUnsafeMutablePointer(to: &deviceInterface) { pointer in
            pointer.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { rebounded in
                plugin.pointee?.pointee.QueryInterface(
                    plugin,
                    CFUUIDGetUUIDBytes(makeUSBDeviceInterfaceID942()),
                    rebounded
                ) ?? EINVAL
            }
        }

        guard queryResult == S_OK, let deviceInterface, let device = deviceInterface.pointee else {
            throw CameraControlError.backendFailure(
                "QueryInterface for IOUSBDeviceInterface942 failed with result 0x\(String(format: "%08X", queryResult))."
            )
        }
        defer {
            _ = device.pointee.Release(deviceInterface)
        }

        let openResult: IOReturn
        switch plan.preferredOpenMode {
        case .standardOpen:
            openResult = device.pointee.USBDeviceOpen(deviceInterface)
        case .seizeIfNeeded:
            openResult = device.pointee.USBDeviceOpenSeize(deviceInterface)
        }

        let deviceIsOpen = openResult == kIOReturnSuccess
        if deviceIsOpen {
            defer {
                _ = device.pointee.USBDeviceClose(deviceInterface)
            }
        }

        var configurationCount: UInt8 = 0
        if deviceIsOpen {
            let configResult = device.pointee.GetNumberOfConfigurations(deviceInterface, &configurationCount)
            guard configResult == kIOReturnSuccess else {
                throw CameraControlError.backendFailure(
                    "GetNumberOfConfigurations failed for registry entry 0x\(String(format: "%016llX", resolvedService.registryEntryID)) with result 0x\(String(format: "%08X", configResult))."
                )
            }
        }

        let interfaces = try interfaceEnumerator.enumerate(deviceInterface: deviceInterface)
        let controlInterface = RawUVCControlInterfaceSelector.select(from: interfaces)

        return RawUVCOpenedDeviceInterface(
            registryEntryID: resolvedService.registryEntryID,
            configurationCount: configurationCount,
            deviceOpenResult: deviceIsOpen ? nil : openResult,
            interfaces: interfaces,
            controlInterface: controlInterface
        )
    }
}

private func makeUSBDeviceUserClientTypeID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xD4,
        0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    )
}

private func makeIOCFPlugInInterfaceID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
        0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F
    )
}

private func makeUSBDeviceInterfaceID942() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        kCFAllocatorSystemDefault,
        0x56, 0xAD, 0x08, 0x9D, 0x87, 0x8D, 0x4B, 0xEA,
        0xA1, 0xF5, 0x2C, 0x8D, 0xC4, 0x3E, 0x8A, 0x98
    )
}
#endif
