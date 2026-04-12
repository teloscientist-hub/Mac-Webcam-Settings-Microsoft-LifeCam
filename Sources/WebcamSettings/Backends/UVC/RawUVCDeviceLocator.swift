import Foundation

protocol RawUVCDeviceLocating: Sendable {
    func resolve(device: CameraDeviceDescriptor) async -> RawUVCDeviceResolution?
}

struct RawUVCDeviceResolution: Sendable, Equatable {
    let manufacturer: String?
    let productName: String?
    let vendorID: Int?
    let productID: Int?
    let serialNumber: String?
    let registryEntryID: UInt64?
    let serviceClassName: String?

    var summary: String {
        var parts: [String] = []

        if let manufacturer, manufacturer.isEmpty == false {
            parts.append(manufacturer)
        }

        if let productName, productName.isEmpty == false {
            parts.append(productName)
        }

        if let vendorID, let productID {
            parts.append(String(format: "VID:PID %04X:%04X", vendorID, productID))
        } else if let vendorID {
            parts.append(String(format: "VID %04X", vendorID))
        } else if let productID {
            parts.append(String(format: "PID %04X", productID))
        }

        if let serialNumber, serialNumber.isEmpty == false {
            parts.append("serial \(serialNumber)")
        }

        if let registryEntryID {
            parts.append(String(format: "registry 0x%016llX", registryEntryID))
        }

        return parts.isEmpty ? "unresolved USB target" : parts.joined(separator: ", ")
    }
}

struct RawUVCTransportTarget: Sendable, Equatable {
    enum MatchQuality: String, Sendable, Equatable {
        case exactSerial
        case vendorProduct
        case nameOnly
    }

    let manufacturer: String?
    let productName: String?
    let vendorID: Int?
    let productID: Int?
    let serialNumber: String?
    let avFoundationUniqueID: String?
    let backendIdentifier: String?
    let registryEntryID: UInt64?
    let serviceClassName: String?
    let matchQuality: MatchQuality

    var summary: String {
        var parts: [String] = []

        if let manufacturer, manufacturer.isEmpty == false {
            parts.append(manufacturer)
        }

        if let productName, productName.isEmpty == false {
            parts.append(productName)
        }

        if let vendorID, let productID {
            parts.append(String(format: "VID:PID %04X:%04X", vendorID, productID))
        }

        if let serialNumber, serialNumber.isEmpty == false {
            parts.append("serial \(serialNumber)")
        }

        parts.append("match \(matchQuality.rawValue)")

        if let registryEntryID {
            parts.append(String(format: "registry 0x%016llX", registryEntryID))
        }

        if let serviceClassName, serviceClassName.isEmpty == false {
            parts.append("class \(serviceClassName)")
        }

        if let backendIdentifier, backendIdentifier.isEmpty == false {
            parts.append("backend \(backendIdentifier)")
        }

        return parts.joined(separator: ", ")
    }
}

struct RegistryRawUVCDeviceLocator: RawUVCDeviceLocating {
    func resolve(device: CameraDeviceDescriptor) async -> RawUVCDeviceResolution? {
        let metadata = USBDeviceRegistry.metadata(
            matching: device.name,
            manufacturerHint: device.manufacturer
        )

        guard let metadata else {
            return nil
        }

        return RawUVCDeviceResolution(
            manufacturer: metadata.manufacturer,
            productName: metadata.productName,
            vendorID: metadata.vendorID,
            productID: metadata.productID,
            serialNumber: metadata.serialNumber,
            registryEntryID: metadata.registryEntryID,
            serviceClassName: metadata.serviceClassName
        )
    }
}

enum RawUVCDeviceLocatorSupport {
    static func makeTransportTarget(
        for device: CameraDeviceDescriptor,
        resolution: RawUVCDeviceResolution?
    ) -> RawUVCTransportTarget? {
        let manufacturer = resolution?.manufacturer ?? device.manufacturer
        let productName = resolution?.productName ?? device.model ?? device.name
        let vendorID = resolution?.vendorID ?? device.vendorID
        let productID = resolution?.productID ?? device.productID
        let serialNumber = resolution?.serialNumber ?? device.serialNumber
        let registryEntryID = resolution?.registryEntryID
        let serviceClassName = resolution?.serviceClassName

        let matchQuality: RawUVCTransportTarget.MatchQuality
        if serialNumber?.isEmpty == false {
            matchQuality = .exactSerial
        } else if vendorID != nil || productID != nil {
            matchQuality = .vendorProduct
        } else if productName.isEmpty == false {
            matchQuality = .nameOnly
        } else {
            return nil
        }

        return RawUVCTransportTarget(
            manufacturer: manufacturer,
            productName: productName,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serialNumber,
            avFoundationUniqueID: device.avFoundationUniqueID,
            backendIdentifier: device.backendIdentifier,
            registryEntryID: registryEntryID,
            serviceClassName: serviceClassName,
            matchQuality: matchQuality
        )
    }

    static func resolvedTarget(for device: CameraDeviceDescriptor?) -> RawUVCTransportTarget? {
        guard let device else {
            return nil
        }

        let resolution = USBDeviceRegistry.metadata(
            matching: device.name,
            manufacturerHint: device.manufacturer
        ).map {
            RawUVCDeviceResolution(
                manufacturer: $0.manufacturer,
                productName: $0.productName,
                vendorID: $0.vendorID,
                productID: $0.productID,
                serialNumber: $0.serialNumber,
                registryEntryID: $0.registryEntryID,
                serviceClassName: $0.serviceClassName
            )
        }

        return makeTransportTarget(for: device, resolution: resolution)
    }

    static func resolvedTargetSummary(for device: CameraDeviceDescriptor?) -> String {
        guard let target = resolvedTarget(for: device) else {
            return "No raw transport target selected"
        }
        return target.summary
    }
}
