import Foundation

#if canImport(IOKit)
import IOKit
#endif

struct USBDeviceRegistry {
    struct Metadata: Sendable, Equatable {
        let manufacturer: String?
        let productName: String?
        let vendorID: Int?
        let productID: Int?
        let serialNumber: String?
        let registryEntryID: UInt64?
        let serviceClassName: String?
    }

    static func metadata(matching localizedName: String, manufacturerHint: String?) -> Metadata? {
        #if canImport(IOKit)
        let devices = allUSBDevices()

        if let exact = devices.first(where: {
            namesMatch(lhs: $0.productName, rhs: localizedName) &&
            manufacturersMatch(lhs: $0.manufacturer, rhs: manufacturerHint)
        }) {
            return exact
        }

        if let nameOnly = devices.first(where: { namesMatch(lhs: $0.productName, rhs: localizedName) }) {
            return nameOnly
        }

        return devices.first(where: { metadata in
            guard let productName = metadata.productName else { return false }
            return localizedName.localizedCaseInsensitiveContains(productName) || productName.localizedCaseInsensitiveContains(localizedName)
        })
        #else
        _ = localizedName
        _ = manufacturerHint
        return nil
        #endif
    }

    #if canImport(IOKit)
    private static func allUSBDevices() -> [Metadata] {
        ["IOUSBHostDevice", "IOUSBDevice"].flatMap(loadDevices(forClassName:))
    }

    private static func loadDevices(forClassName className: String) -> [Metadata] {
        guard let matchingDictionary = IOServiceMatching(className) else {
            return []
        }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)
        guard result == KERN_SUCCESS else {
            return []
        }

        defer { IOObjectRelease(iterator) }

        var devices: [Metadata] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            devices.append(
                Metadata(
                    manufacturer: copyStringProperty("USB Vendor Name", service: service) ?? copyStringProperty("manufacturer", service: service),
                    productName: copyStringProperty("USB Product Name", service: service) ?? copyStringProperty("product", service: service),
                    vendorID: copyIntProperty("idVendor", service: service),
                    productID: copyIntProperty("idProduct", service: service),
                    serialNumber: copyStringProperty("USB Serial Number", service: service) ?? copyStringProperty("kUSBSerialNumberString", service: service),
                    registryEntryID: copyRegistryEntryID(service),
                    serviceClassName: className
                )
            )
        }

        return devices.filter { $0.productName != nil || $0.vendorID != nil || $0.productID != nil }
    }

    private static func copyStringProperty(_ key: String, service: io_service_t) -> String? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        guard let string = value as? String, string.isEmpty == false else {
            return nil
        }
        return string
    }

    private static func copyIntProperty(_ key: String, service: io_service_t) -> Int? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        guard let number = value as? NSNumber else {
            return nil
        }
        return number.intValue
    }

    private static func copyRegistryEntryID(_ service: io_service_t) -> UInt64? {
        var entryID: UInt64 = 0
        let result = IORegistryEntryGetRegistryEntryID(service, &entryID)
        guard result == KERN_SUCCESS else {
            return nil
        }
        return entryID
    }

    private static func namesMatch(lhs: String?, rhs: String?) -> Bool {
        guard let lhs, let rhs else { return false }
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    private static func manufacturersMatch(lhs: String?, rhs: String?) -> Bool {
        guard let rhs else { return true }
        guard let lhs else { return false }
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
    #endif
}
