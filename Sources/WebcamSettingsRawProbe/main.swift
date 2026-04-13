import Foundation

#if canImport(IOKit)
import IOKit
import IOKit.usb.IOUSBLib

private let targetVendorID: Int = 0x045E
private let targetProductID: Int = 0x0772
private let brightnessSelector: UInt8 = 0x02
private let processingUnitID: UInt8 = 0x04
private let noDataTimeout: UInt32 = 500
private let completionTimeout: UInt32 = 1000

struct ProbeOptions {
    let setBrightness: Int?
    let probeUserClient: Bool
    let probeControlUserClient: Bool
    let probeControlMethods: Bool
    let probeControlScalars: Bool
    let probeProblemControls: Bool
    let probeExtendedControls: Bool

    static func parse() -> ProbeOptions {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let probeUserClient = arguments.contains("--probe-user-client")
        let probeControlUserClient = arguments.contains("--probe-control-user-client")
        let probeControlMethods = arguments.contains("--probe-control-methods")
        let probeControlScalars = arguments.contains("--probe-control-scalars")
        let probeProblemControls = arguments.contains("--probe-problem-controls")
        let probeExtendedControls = arguments.contains("--probe-extended-controls")
        if let flagIndex = arguments.firstIndex(of: "--set-brightness"),
           arguments.indices.contains(flagIndex + 1),
           let value = Int(arguments[flagIndex + 1]) {
            return ProbeOptions(
                setBrightness: value,
                probeUserClient: probeUserClient,
                probeControlUserClient: probeControlUserClient,
                probeControlMethods: probeControlMethods,
                probeControlScalars: probeControlScalars,
                probeProblemControls: probeProblemControls,
                probeExtendedControls: probeExtendedControls
            )
        }
        return ProbeOptions(
            setBrightness: nil,
            probeUserClient: probeUserClient,
            probeControlUserClient: probeControlUserClient,
            probeControlMethods: probeControlMethods,
            probeControlScalars: probeControlScalars,
            probeProblemControls: probeProblemControls,
            probeExtendedControls: probeExtendedControls
        )
    }
}

struct USBMatch {
    let registryEntryID: UInt64
    let serviceClassName: String
    let manufacturer: String?
    let productName: String?
}

struct UVCControlInterface {
    let registryEntryID: UInt64
    let interfaceNumber: UInt8
    let alternateSetting: UInt8
    let owner: String?
}

enum ProbeError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case let .message(message):
            return message
        }
    }
}

@main
struct WebcamSettingsRawProbe {
    static func main() throws {
        let options = ProbeOptions.parse()
        let matches = try findTargetDevices()
        if options.probeUserClient {
            try runUserClientProbe(matches: matches)
            return
        }
        if options.probeControlUserClient {
            try runControlInterfaceUserClientProbe()
            return
        }
        if options.probeControlMethods {
            try runControlInterfaceMethodProbe()
            return
        }
        if options.probeControlScalars {
            try runControlInterfaceScalarProbe()
            return
        }
        if options.probeProblemControls {
            try runProblemControlProbe(matches: matches)
            return
        }
        if options.probeExtendedControls {
            try runExtendedControlProbe(matches: matches)
            return
        }
        let (match, deviceInterface) = try openFirstAvailableDeviceInterface(matches: matches)
        print("Matched device: \(match.manufacturer ?? "Unknown") \(match.productName ?? "Unknown") [\(match.serviceClassName)] registry=0x\(hex(match.registryEntryID, width: 16))")
        defer { _ = deviceInterface.interface.pointee.Release(deviceInterface.pointer) }

        let openResult = deviceInterface.interface.pointee.USBDeviceOpenSeize(deviceInterface.pointer)
        guard openResult == kIOReturnSuccess else {
            throw ProbeError.message("USBDeviceOpenSeize failed: 0x\(hex(openResult, width: 8))")
        }
        defer { _ = deviceInterface.interface.pointee.USBDeviceClose(deviceInterface.pointer) }

        let controlInterface = try findControlInterface(deviceInterface: deviceInterface.pointer)
        print("Selected control interface: if=\(controlInterface.interfaceNumber) alt=\(controlInterface.alternateSetting) registry=0x\(hex(controlInterface.registryEntryID, width: 16))")

        let current = try getBrightness(
            deviceInterface: deviceInterface.pointer,
            interfaceNumber: controlInterface.interfaceNumber
        )
        print("Current brightness: \(current)")

        if let setBrightness = options.setBrightness {
            try setBrightnessValue(
                setBrightness,
                deviceInterface: deviceInterface.pointer,
                interfaceNumber: controlInterface.interfaceNumber
            )
            print("Set brightness to: \(setBrightness)")

            let updated = try getBrightness(
                deviceInterface: deviceInterface.pointer,
                interfaceNumber: controlInterface.interfaceNumber
            )
            print("Brightness after set: \(updated)")
        } else {
            print("No write attempted. Pass --set-brightness <value> to test a write.")
            print("Pass --probe-user-client to test IOServiceAuthorize/IOServiceOpen on the matched USB services.")
            print("Pass --probe-control-user-client to test IOServiceAuthorize/IOServiceOpen on LifeCam control interfaces.")
            print("Pass --probe-control-methods to sweep a few IOConnect external-method selectors on the LifeCam control interface.")
            print("Pass --probe-control-scalars to sweep small scalar inputs against the live control-interface selectors.")
            print("Pass --probe-problem-controls to exercise power-line, white-balance-auto, and focus-auto/manual directly.")
            print("Pass --probe-extended-controls to exercise exposure, zoom, and pan/tilt directly.")
        }
    }

    private static func runProblemControlProbe(matches: [USBMatch]) throws {
        let (_, deviceInterface) = try openFirstAvailableDeviceInterface(matches: matches)
        defer { _ = deviceInterface.interface.pointee.Release(deviceInterface.pointer) }

        let openResult = deviceInterface.interface.pointee.USBDeviceOpenSeize(deviceInterface.pointer)
        guard openResult == kIOReturnSuccess else {
            throw ProbeError.message("USBDeviceOpenSeize failed: 0x\(hex(openResult, width: 8))")
        }
        defer { _ = deviceInterface.interface.pointee.USBDeviceClose(deviceInterface.pointer) }

        let controlInterface = try findControlInterface(deviceInterface: deviceInterface.pointer)
        print("Selected control interface: if=\(controlInterface.interfaceNumber) alt=\(controlInterface.alternateSetting) registry=0x\(hex(controlInterface.registryEntryID, width: 16))")

        try probeEnumControl(
            name: "Power Line Frequency",
            selector: 0x05,
            unitID: 0x04,
            interfaceNumber: controlInterface.interfaceNumber,
            writeValues: [1, 0, 2],
            deviceInterface: deviceInterface.pointer
        )

        try probeBooleanControl(
            name: "White Balance Auto",
            selector: 0x0B,
            unitID: 0x04,
            interfaceNumber: controlInterface.interfaceNumber,
            deviceInterface: deviceInterface.pointer
        )

        try probeBooleanControl(
            name: "Focus Auto",
            selector: 0x08,
            unitID: 0x01,
            interfaceNumber: controlInterface.interfaceNumber,
            deviceInterface: deviceInterface.pointer
        )

        try probeInt16Control(
            name: "Focus",
            selector: 0x06,
            unitID: 0x01,
            interfaceNumber: controlInterface.interfaceNumber,
            writeValues: [20, 5],
            deviceInterface: deviceInterface.pointer
        )
    }

    private static func runExtendedControlProbe(matches: [USBMatch]) throws {
        let (_, deviceInterface) = try openFirstAvailableDeviceInterface(matches: matches)
        defer { _ = deviceInterface.interface.pointee.Release(deviceInterface.pointer) }

        let openResult = deviceInterface.interface.pointee.USBDeviceOpenSeize(deviceInterface.pointer)
        guard openResult == kIOReturnSuccess else {
            throw ProbeError.message("USBDeviceOpenSeize failed: 0x\(hex(openResult, width: 8))")
        }
        defer { _ = deviceInterface.interface.pointee.USBDeviceClose(deviceInterface.pointer) }

        let controlInterface = try findControlInterface(deviceInterface: deviceInterface.pointer)
        print("Selected control interface: if=\(controlInterface.interfaceNumber) alt=\(controlInterface.alternateSetting) registry=0x\(hex(controlInterface.registryEntryID, width: 16))")

        do {
            try probeEnumControl(
            name: "Exposure Mode",
            selector: 0x02,
            unitID: 0x01,
            interfaceNumber: controlInterface.interfaceNumber,
            writeValues: [0x01, 0x08],
            deviceInterface: deviceInterface.pointer
        )
        } catch {
            print("Exposure Mode probe failed: \(error)")
        }

        do {
            try probeInt32Control(
            name: "Exposure Time",
            selector: 0x04,
            unitID: 0x01,
            interfaceNumber: controlInterface.interfaceNumber,
            writeValues: [300, 30],
            deviceInterface: deviceInterface.pointer
        )
        } catch {
            print("Exposure Time probe failed: \(error)")
        }

        do {
            try probeInt16Control(
            name: "Zoom",
            selector: 0x0B,
            unitID: 0x01,
            interfaceNumber: controlInterface.interfaceNumber,
            writeValues: [40, 0],
            deviceInterface: deviceInterface.pointer
        )
        } catch {
            print("Zoom probe failed: \(error)")
        }

        do {
            try probeInt32Control(
            name: "Pan",
            selector: 0x0D,
            unitID: 0x01,
            interfaceNumber: controlInterface.interfaceNumber,
            writeValues: [3600, 0],
            deviceInterface: deviceInterface.pointer
        )
        } catch {
            print("Pan probe failed: \(error)")
        }

        do {
            try probeInt32Control(
            name: "Tilt",
            selector: 0x0E,
            unitID: 0x01,
            interfaceNumber: controlInterface.interfaceNumber,
            writeValues: [900, 0],
            deviceInterface: deviceInterface.pointer
        )
        } catch {
            print("Tilt probe failed: \(error)")
        }
    }

    private static func runUserClientProbe(matches: [USBMatch]) throws {
        print("Probing IOService authorization and user-client open for matching LifeCam services...")

        for match in matches {
            guard let matching = IORegistryEntryIDMatching(match.registryEntryID) else {
                print("[\(match.serviceClassName)] registry=0x\(hex(match.registryEntryID, width: 16)) could not rebuild the matching dictionary")
                continue
            }

            let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
            guard service != 0 else {
                print("[\(match.serviceClassName)] registry=0x\(hex(match.registryEntryID, width: 16)) could not reacquire the service")
                continue
            }
            defer { IOObjectRelease(service) }

            let authorizeResult = IOServiceAuthorize(service, 0)
            var connect: io_connect_t = 0
            let openResult = IOServiceOpen(service, mach_task_self_, 0, &connect)
            if openResult == KERN_SUCCESS {
                IOServiceClose(connect)
            }

            print(
                "[\(match.serviceClassName)] registry=0x\(hex(match.registryEntryID, width: 16)) " +
                "authorize=0x\(hex(authorizeResult, width: 8)) open(type:0)=0x\(hex(openResult, width: 8))"
            )
        }
    }

    private static func runControlInterfaceUserClientProbe() throws {
        let interfaces = try findLifeCamControlInterfaces()
        print("Probing IOService authorization and user-client open for \(interfaces.count) LifeCam control interface(s)...")

        for interface in interfaces {
            guard let matching = IORegistryEntryIDMatching(interface.registryEntryID) else {
                print("control interface if=\(interface.interfaceNumber) registry=0x\(hex(interface.registryEntryID, width: 16)) could not rebuild the matching dictionary")
                continue
            }

            let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
            guard service != 0 else {
                print("control interface if=\(interface.interfaceNumber) registry=0x\(hex(interface.registryEntryID, width: 16)) could not reacquire the service")
                continue
            }
            defer { IOObjectRelease(service) }

            let authorizeResult = IOServiceAuthorize(service, 0)
            let typeResults = (0...4).map { type -> String in
                var connect: io_connect_t = 0
                let result = IOServiceOpen(service, mach_task_self_, UInt32(type), &connect)
                if result == KERN_SUCCESS {
                    IOServiceClose(connect)
                }
                return "type:\(type)=0x\(hex(result, width: 8))"
            }.joined(separator: " ")

            print(
                "control interface if=\(interface.interfaceNumber) alt=\(interface.alternateSetting) registry=0x\(hex(interface.registryEntryID, width: 16)) " +
                "owner=\(interface.owner ?? "n/a") authorize=0x\(hex(authorizeResult, width: 8)) \(typeResults)"
            )
        }
    }

    private static func runControlInterfaceMethodProbe() throws {
        let interfaces = try findLifeCamControlInterfaces()
        guard let interface = interfaces.first else {
            throw ProbeError.message("No LifeCam control interface was available for method probing.")
        }

        print("Probing IOConnect external-method selectors on control interface if=\(interface.interfaceNumber) registry=0x\(hex(interface.registryEntryID, width: 16)) owner=\(interface.owner ?? "n/a")")

        for type in 0...1 {
            guard let matching = IORegistryEntryIDMatching(interface.registryEntryID) else {
                throw ProbeError.message("Could not rebuild a match dictionary for control interface registry 0x\(hex(interface.registryEntryID, width: 16)).")
            }

            let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
            guard service != 0 else {
                throw ProbeError.message("Could not reacquire control interface registry 0x\(hex(interface.registryEntryID, width: 16)).")
            }

            var connect: io_connect_t = 0
            let openResult = IOServiceOpen(service, mach_task_self_, UInt32(type), &connect)
            IOObjectRelease(service)
            guard openResult == KERN_SUCCESS else {
                print("type:\(type) open failed: 0x\(hex(openResult, width: 8))")
                continue
            }

            print("type:\(type) open succeeded")
            for selector in 0...12 {
                let methodResult = callMethod(connect: connect, selector: UInt32(selector))
                let scalarResult = callScalar(connect: connect, selector: UInt32(selector))
                let structResult = callStruct(connect: connect, selector: UInt32(selector))
                print(
                    "  selector:\(selector) " +
                    "method=\(methodResult) " +
                    "scalar=\(scalarResult) " +
                    "struct=\(structResult)"
                )
            }
            IOServiceClose(connect)
        }
    }

    private static func runControlInterfaceScalarProbe() throws {
        let interfaces = try findLifeCamControlInterfaces()
        guard let interface = interfaces.first else {
            throw ProbeError.message("No LifeCam control interface was available for scalar probing.")
        }

        let targets: [(type: UInt32, selector: UInt32)] = [
            (0, 5),
            (0, 6),
            (1, 2)
        ]

        print("Probing scalar-input variants on control interface if=\(interface.interfaceNumber) registry=0x\(hex(interface.registryEntryID, width: 16)) owner=\(interface.owner ?? "n/a")")

        for target in targets {
            guard let matching = IORegistryEntryIDMatching(interface.registryEntryID) else {
                throw ProbeError.message("Could not rebuild a match dictionary for control interface registry 0x\(hex(interface.registryEntryID, width: 16)).")
            }

            let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
            guard service != 0 else {
                throw ProbeError.message("Could not reacquire control interface registry 0x\(hex(interface.registryEntryID, width: 16)).")
            }

            var connect: io_connect_t = 0
            let openResult = IOServiceOpen(service, mach_task_self_, target.type, &connect)
            IOObjectRelease(service)
            guard openResult == KERN_SUCCESS else {
                print("type:\(target.type) selector:\(target.selector) open failed: 0x\(hex(openResult, width: 8))")
                continue
            }

            print("type:\(target.type) selector:\(target.selector)")
            for input in 0...8 {
                let result = callScalarWithInput(connect: connect, selector: target.selector, input: UInt64(input))
                print("  input:\(input) -> \(result)")
            }
            IOServiceClose(connect)
        }
    }

    private static func findTargetDevices() throws -> [USBMatch] {
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
                let vendorID = copyIntProperty("idVendor", service: service)
                let productID = copyIntProperty("idProduct", service: service)

                guard vendorID == targetVendorID, productID == targetProductID else {
                    continue
                }

                var registryEntryID: UInt64 = 0
                guard IORegistryEntryGetRegistryEntryID(service, &registryEntryID) == KERN_SUCCESS else {
                    continue
                }

                matches.append(
                    USBMatch(
                        registryEntryID: registryEntryID,
                        serviceClassName: className,
                        manufacturer: copyStringProperty("USB Vendor Name", service: service) ?? copyStringProperty("manufacturer", service: service),
                        productName: copyStringProperty("USB Product Name", service: service) ?? copyStringProperty("product", service: service)
                    )
                )
            }
        }

        guard matches.isEmpty == false else {
            throw ProbeError.message("Could not find Microsoft LifeCam Studio (VID:PID 045E:0772).")
        }

        return matches
    }

    private static func openFirstAvailableDeviceInterface(
        matches: [USBMatch]
    ) throws -> (USBMatch, (pointer: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>, interface: UnsafeMutablePointer<IOUSBDeviceInterface942>)) {
        var failures: [String] = []

        for match in matches {
            do {
                let deviceInterface = try openDeviceInterface(registryEntryID: match.registryEntryID)
                return (match, deviceInterface)
            } catch {
                failures.append("[\(match.serviceClassName) 0x\(hex(match.registryEntryID, width: 16))] \(error)")
            }
        }

        throw ProbeError.message("Failed to open any matching LifeCam USB service: \(failures.joined(separator: "; "))")
    }

    private static func openDeviceInterface(registryEntryID: UInt64) throws -> (pointer: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>, interface: UnsafeMutablePointer<IOUSBDeviceInterface942>) {
        guard let matching = IORegistryEntryIDMatching(registryEntryID) else {
            throw ProbeError.message("Failed to build match dictionary for registry entry 0x\(hex(registryEntryID, width: 16)).")
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            throw ProbeError.message("Could not reacquire device service for registry entry 0x\(hex(registryEntryID, width: 16)).")
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
            throw ProbeError.message("IOCreatePlugInInterfaceForService failed: 0x\(hex(pluginResult, width: 8))")
        }
        defer { _ = plugin.pointee?.pointee.Release(plugin) }

        var deviceInterfacePointer: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>?
        let queryResult: HRESULT = withUnsafeMutablePointer(to: &deviceInterfacePointer) { pointer in
            pointer.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { rebound in
                plugin.pointee?.pointee.QueryInterface(
                    plugin,
                    CFUUIDGetUUIDBytes(makeUSBDeviceInterfaceID942()),
                    rebound
                ) ?? EINVAL
            }
        }

        guard queryResult == S_OK,
              let deviceInterfacePointer,
              let deviceInterface = deviceInterfacePointer.pointee
        else {
            throw ProbeError.message("QueryInterface for IOUSBDeviceInterface942 failed: 0x\(hex(queryResult, width: 8))")
        }

        return (deviceInterfacePointer, deviceInterface)
    }

    private static func findControlInterface(
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws -> UVCControlInterface {
        guard let device = deviceInterface.pointee else {
            throw ProbeError.message("Device interface unexpectedly nil during interface enumeration.")
        }

        var request = IOUSBFindInterfaceRequest(
            bInterfaceClass: 0xFFFF,
            bInterfaceSubClass: 0xFFFF,
            bInterfaceProtocol: 0xFFFF,
            bAlternateSetting: 0xFFFF
        )

        var iterator: io_iterator_t = 0
        let createResult = device.pointee.CreateInterfaceIterator(deviceInterface, &request, &iterator)
        guard createResult == kIOReturnSuccess else {
            throw ProbeError.message("CreateInterfaceIterator failed: 0x\(hex(createResult, width: 8))")
        }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let candidate = try openInterface(service: service) {
                return candidate
            }
        }

        throw ProbeError.message("Could not find a UVC control interface.")
    }

    private static func openInterface(service: io_service_t) throws -> UVCControlInterface? {
        var registryEntryID: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(service, &registryEntryID) == KERN_SUCCESS else {
            return nil
        }
        let owner = copyStringProperty("UsbExclusiveOwner", service: service)

        var score: Int32 = 0
        var plugin: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        let pluginResult = IOCreatePlugInInterfaceForService(
            service,
            makeUSBInterfaceUserClientTypeID(),
            makeIOCFPlugInInterfaceID(),
            &plugin,
            &score
        )
        guard pluginResult == kIOReturnSuccess, let plugin else {
            return nil
        }
        defer { _ = plugin.pointee?.pointee.Release(plugin) }

        var interfacePointer: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface942>?>?
        let queryResult: HRESULT = withUnsafeMutablePointer(to: &interfacePointer) { pointer in
            pointer.withMemoryRebound(to: Optional<LPVOID>.self, capacity: 1) { rebound in
                plugin.pointee?.pointee.QueryInterface(
                    plugin,
                    CFUUIDGetUUIDBytes(makeUSBInterfaceInterfaceID942()),
                    rebound
                ) ?? EINVAL
            }
        }

        guard queryResult == S_OK,
              let interfacePointer,
              let interface = interfacePointer.pointee
        else {
            return nil
        }
        defer { _ = interface.pointee.Release(interfacePointer) }

        var interfaceClass: UInt8 = 0
        var interfaceSubClass: UInt8 = 0
        var interfaceNumber: UInt8 = 0
        var alternateSetting: UInt8 = 0

        guard interface.pointee.GetInterfaceClass(interfacePointer, &interfaceClass) == kIOReturnSuccess,
              interface.pointee.GetInterfaceSubClass(interfacePointer, &interfaceSubClass) == kIOReturnSuccess,
              interface.pointee.GetInterfaceNumber(interfacePointer, &interfaceNumber) == kIOReturnSuccess,
              interface.pointee.GetAlternateSetting(interfacePointer, &alternateSetting) == kIOReturnSuccess
        else {
            return nil
        }

        guard interfaceClass == 0x0E, interfaceSubClass == 0x01 else {
            return nil
        }

        return UVCControlInterface(
            registryEntryID: registryEntryID,
            interfaceNumber: interfaceNumber,
            alternateSetting: alternateSetting,
            owner: owner
        )
    }

    private static func findLifeCamControlInterfaces() throws -> [UVCControlInterface] {
        guard let dictionary = IOServiceMatching("IOUSBHostInterface") else {
            throw ProbeError.message("Failed to build IOUSBHostInterface matching dictionary.")
        }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, dictionary, &iterator)
        guard result == KERN_SUCCESS else {
            throw ProbeError.message("IOServiceGetMatchingServices(IOUSBHostInterface) failed: 0x\(hex(result, width: 8))")
        }
        defer { IOObjectRelease(iterator) }

        var interfaces: [UVCControlInterface] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            guard copyIntProperty("idVendor", service: service) == targetVendorID,
                  copyIntProperty("idProduct", service: service) == targetProductID,
                  copyIntProperty("bInterfaceClass", service: service) == 0x0E,
                  copyIntProperty("bInterfaceSubClass", service: service) == 0x01 else {
                continue
            }

            var registryEntryID: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(service, &registryEntryID) == KERN_SUCCESS else {
                continue
            }

            let interfaceNumber = UInt8(clamping: copyIntProperty("bInterfaceNumber", service: service) ?? 0)
            let alternateSetting = UInt8(clamping: copyIntProperty("bAlternateSetting", service: service) ?? 0)
            let owner = copyStringProperty("UsbExclusiveOwner", service: service)
            interfaces.append(
                UVCControlInterface(
                    registryEntryID: registryEntryID,
                    interfaceNumber: interfaceNumber,
                    alternateSetting: alternateSetting,
                    owner: owner
                )
            )
        }

        guard interfaces.isEmpty == false else {
            throw ProbeError.message("Could not find a LifeCam UVC control interface via IOUSBHostInterface.")
        }

        return interfaces.sorted {
            if $0.interfaceNumber == $1.interfaceNumber {
                return $0.alternateSetting < $1.alternateSetting
            }
            return $0.interfaceNumber < $1.interfaceNumber
        }
    }

    private static func getBrightness(
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>,
        interfaceNumber: UInt8
    ) throws -> Int {
        let payload = try readControl(
            selector: brightnessSelector,
            unitID: processingUnitID,
            length: 2,
            interfaceNumber: interfaceNumber,
            requestType: 0xA1,
            request: 0x81,
            deviceInterface: deviceInterface
        )
        let value = Int16(bitPattern: UInt16(payload[0]) | (UInt16(payload[1]) << 8))
        return Int(value)
    }

    private static func setBrightnessValue(
        _ brightness: Int,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>,
        interfaceNumber: UInt8
    ) throws {
        let clamped = max(Int(Int16.min), min(Int(Int16.max), brightness))
        let signed = Int16(clamped)
        let payload = Data([
            UInt8(truncatingIfNeeded: signed),
            UInt8(truncatingIfNeeded: signed >> 8)
        ])
        try writeControl(
            selector: brightnessSelector,
            unitID: processingUnitID,
            payload: payload,
            interfaceNumber: interfaceNumber,
            requestType: 0x21,
            request: 0x01,
            deviceInterface: deviceInterface
        )
    }

    private static func probeEnumControl(
        name: String,
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        writeValues: [UInt8],
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws {
        let original = try readUInt8Control(selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
        print("\(name) original: \(original)")
        for value in writeValues {
            do {
                try writeUInt8Control(value, selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
                let updated = try readUInt8Control(selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
                print("\(name) set \(value) -> \(updated)")
            } catch {
                print("\(name) set \(value) failed: \(error)")
            }
        }
        try? writeUInt8Control(original, selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
    }

    private static func probeBooleanControl(
        name: String,
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws {
        let original = try readUInt8Control(selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
        print("\(name) original: \(original)")
        for value: UInt8 in [original == 0 ? 1 : 0, original] {
            do {
                try writeUInt8Control(value, selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
                let updated = try readUInt8Control(selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
                print("\(name) set \(value) -> \(updated)")
            } catch {
                print("\(name) set \(value) failed: \(error)")
            }
        }
        try? writeUInt8Control(original, selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
    }

    private static func probeInt16Control(
        name: String,
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        writeValues: [Int16],
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws {
        let original = try readInt16Control(selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
        print("\(name) original: \(original)")
        for value in writeValues {
            do {
                try writeInt16Control(value, selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
                let updated = try readInt16Control(selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
                print("\(name) set \(value) -> \(updated)")
            } catch {
                print("\(name) set \(value) failed: \(error)")
            }
        }
        try? writeInt16Control(original, selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
    }

    private static func probeInt32Control(
        name: String,
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        writeValues: [Int32],
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws {
        let original = try readInt32Control(selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
        print("\(name) original: \(original)")
        for value in writeValues {
            do {
                try writeInt32Control(value, selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
                let updated = try readInt32Control(selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
                print("\(name) set \(value) -> \(updated)")
            } catch {
                print("\(name) set \(value) failed: \(error)")
            }
        }
        try? writeInt32Control(original, selector: selector, unitID: unitID, interfaceNumber: interfaceNumber, deviceInterface: deviceInterface)
    }

    private static func readUInt8Control(
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws -> UInt8 {
        let payload = try readControl(
            selector: selector,
            unitID: unitID,
            length: 1,
            interfaceNumber: interfaceNumber,
            requestType: 0xA1,
            request: 0x81,
            deviceInterface: deviceInterface
        )
        return payload[0]
    }

    private static func writeUInt8Control(
        _ value: UInt8,
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws {
        try writeControl(
            selector: selector,
            unitID: unitID,
            payload: Data([value]),
            interfaceNumber: interfaceNumber,
            requestType: 0x21,
            request: 0x01,
            deviceInterface: deviceInterface
        )
    }

    private static func readInt16Control(
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws -> Int16 {
        let payload = try readControl(
            selector: selector,
            unitID: unitID,
            length: 2,
            interfaceNumber: interfaceNumber,
            requestType: 0xA1,
            request: 0x81,
            deviceInterface: deviceInterface
        )
        return Int16(bitPattern: UInt16(payload[0]) | (UInt16(payload[1]) << 8))
    }

    private static func writeInt16Control(
        _ value: Int16,
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws {
        let payload = Data([
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value >> 8)
        ])
        try writeControl(
            selector: selector,
            unitID: unitID,
            payload: payload,
            interfaceNumber: interfaceNumber,
            requestType: 0x21,
            request: 0x01,
            deviceInterface: deviceInterface
        )
    }

    private static func readInt32Control(
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws -> Int32 {
        let payload = try readControl(
            selector: selector,
            unitID: unitID,
            length: 4,
            interfaceNumber: interfaceNumber,
            requestType: 0xA1,
            request: 0x81,
            deviceInterface: deviceInterface
        )
        return Int32(bitPattern: UInt32(payload[0]) | (UInt32(payload[1]) << 8) | (UInt32(payload[2]) << 16) | (UInt32(payload[3]) << 24))
    }

    private static func writeInt32Control(
        _ value: Int32,
        selector: UInt8,
        unitID: UInt8,
        interfaceNumber: UInt8,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws {
        let payload = Data([
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 24)
        ])
        try writeControl(
            selector: selector,
            unitID: unitID,
            payload: payload,
            interfaceNumber: interfaceNumber,
            requestType: 0x21,
            request: 0x01,
            deviceInterface: deviceInterface
        )
    }

    private static func readControl(
        selector: UInt8,
        unitID: UInt8,
        length: Int,
        interfaceNumber: UInt8,
        requestType: UInt8,
        request: UInt8,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws -> Data {
        var payload = Data(count: length)
        let effectiveIndex = UInt16(unitID) << 8 | UInt16(interfaceNumber)
        let result: IOReturn = payload.withUnsafeMutableBytes { buffer in
            var usbRequest = IOUSBDevRequestTO(
                bmRequestType: requestType,
                bRequest: request,
                wValue: UInt16(selector) << 8,
                wIndex: effectiveIndex,
                wLength: UInt16(length),
                pData: buffer.baseAddress,
                wLenDone: 0,
                noDataTimeout: noDataTimeout,
                completionTimeout: completionTimeout
            )
            return deviceInterface.pointee?.pointee.DeviceRequestTO(deviceInterface, &usbRequest) ?? kIOReturnError
        }
        guard result == kIOReturnSuccess else {
            throw ProbeError.message("GET/READ failed selector 0x\(hex(selector, width: 2)) unit 0x\(hex(unitID, width: 2)): 0x\(hex(result, width: 8))")
        }
        return payload
    }

    private static func writeControl(
        selector: UInt8,
        unitID: UInt8,
        payload: Data,
        interfaceNumber: UInt8,
        requestType: UInt8,
        request: UInt8,
        deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    ) throws {
        var mutablePayload = payload
        let effectiveIndex = UInt16(unitID) << 8 | UInt16(interfaceNumber)
        let result: IOReturn = mutablePayload.withUnsafeMutableBytes { buffer in
            var usbRequest = IOUSBDevRequestTO(
                bmRequestType: requestType,
                bRequest: request,
                wValue: UInt16(selector) << 8,
                wIndex: effectiveIndex,
                wLength: UInt16(payload.count),
                pData: buffer.baseAddress,
                wLenDone: 0,
                noDataTimeout: noDataTimeout,
                completionTimeout: completionTimeout
            )
            return deviceInterface.pointee?.pointee.DeviceRequestTO(deviceInterface, &usbRequest) ?? kIOReturnError
        }
        guard result == kIOReturnSuccess else {
            throw ProbeError.message("SET/WRITE failed selector 0x\(hex(selector, width: 2)) unit 0x\(hex(unitID, width: 2)): 0x\(hex(result, width: 8))")
        }
    }
}

private func copyStringProperty(_ key: String, service: io_service_t) -> String? {
    guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
        return nil
    }
    return value as? String
}

private func copyIntProperty(_ key: String, service: io_service_t) -> Int? {
    guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
        return nil
    }
    return (value as? NSNumber)?.intValue
}

private func callMethod(connect: io_connect_t, selector: UInt32) -> String {
    var outputScalar: UInt64 = 0
    var outputScalarCount: UInt32 = 1
    let result = withUnsafeMutablePointer(to: &outputScalar) { outputPointer in
        IOConnectCallMethod(
            connect,
            selector,
            nil,
            0,
            nil,
            0,
            outputPointer,
            &outputScalarCount,
            nil,
            nil
        )
    }
    return "0x\(hex(result, width: 8))/count:\(outputScalarCount)/0x\(hex(outputScalar, width: 16))"
}

private func callScalar(connect: io_connect_t, selector: UInt32) -> String {
    var outputScalar: UInt64 = 0
    var outputScalarCount: UInt32 = 1
    let result = withUnsafeMutablePointer(to: &outputScalar) { outputPointer in
        IOConnectCallScalarMethod(
            connect,
            selector,
            nil,
            0,
            outputPointer,
            &outputScalarCount
        )
    }
    return "0x\(hex(result, width: 8))/count:\(outputScalarCount)/0x\(hex(outputScalar, width: 16))"
}

private func callScalarWithInput(connect: io_connect_t, selector: UInt32, input: UInt64) -> String {
    var inputScalar = input
    var outputScalar: UInt64 = 0
    var outputScalarCount: UInt32 = 1
    let result = withUnsafePointer(to: &inputScalar) { inputPointer in
        withUnsafeMutablePointer(to: &outputScalar) { outputPointer in
            IOConnectCallScalarMethod(
                connect,
                selector,
                inputPointer,
                1,
                outputPointer,
                &outputScalarCount
            )
        }
    }
    return "0x\(hex(result, width: 8))/count:\(outputScalarCount)/0x\(hex(outputScalar, width: 16))"
}

private func callStruct(connect: io_connect_t, selector: UInt32) -> String {
    var output = [UInt8](repeating: 0, count: 64)
    var outputCount = MemoryLayout.size(ofValue: output)
    let result = output.withUnsafeMutableBytes { outputBuffer in
        IOConnectCallStructMethod(
            connect,
            selector,
            nil,
            0,
            outputBuffer.baseAddress,
            &outputCount
        )
    }
    return "0x\(hex(result, width: 8))/count:\(outputCount)"
}

private func makeUSBDeviceUserClientTypeID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xD4,
        0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
    )
}

private func makeUSBInterfaceUserClientTypeID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x2d, 0x97, 0x86, 0xc6, 0x9e, 0xf3, 0x11, 0xD4,
        0xad, 0x51, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61
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

private func makeUSBInterfaceInterfaceID942() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        kCFAllocatorSystemDefault,
        0x87, 0x52, 0x66, 0x3B, 0xC0, 0x7B, 0x4B, 0xAE,
        0x95, 0x84, 0x22, 0x03, 0x2F, 0xAB, 0x9C, 0x5A
    )
}

private func hex<T: BinaryInteger>(_ value: T, width: Int) -> String {
    String(format: "%0\(width)X", Int64(value))
}

#else
@main
struct WebcamSettingsRawProbe {
    static func main() {
        print("WebcamSettingsRawProbe requires IOKit and can only run on macOS.")
    }
}
#endif
