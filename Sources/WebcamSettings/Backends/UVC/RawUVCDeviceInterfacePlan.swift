import Foundation

struct RawUVCDeviceInterfacePlan: Sendable, Equatable {
    struct UUIDPlan: Sendable, Equatable {
        let pluginType: String
        let pluginInterface: String
        let deviceInterface: String
    }

    let target: RawUVCTransportTarget
    let resolvedService: RawUVCResolvedIOKitService?
    let uuidPlan: UUIDPlan
    let preferredOpenMode: OpenMode
    let shouldEnumerateInterfaces: Bool

    enum OpenMode: String, Sendable, Equatable {
        case standardOpen
        case seizeIfNeeded
    }

    var summary: String {
        "\(preferredOpenMode.rawValue), pluginType=\(uuidPlan.pluginType), pluginInterface=\(uuidPlan.pluginInterface), deviceInterface=\(uuidPlan.deviceInterface), enumerateInterfaces=\(shouldEnumerateInterfaces), target=[\(target.summary)]"
    }
}

enum RawUVCDeviceInterfacePlanner {
    static func makePlan(
        target: RawUVCTransportTarget,
        resolvedService: RawUVCResolvedIOKitService?
    ) -> RawUVCDeviceInterfacePlan {
        RawUVCDeviceInterfacePlan(
            target: target,
            resolvedService: resolvedService,
            uuidPlan: .init(
                pluginType: "kIOUSBDeviceUserClientTypeID",
                pluginInterface: "kIOCFPlugInInterfaceID",
                deviceInterface: "kIOUSBDeviceInterfaceID942"
            ),
            // Prefer seizing the device for direct control requests so preview ownership
            // does not trivially block the first real hardware-brightness test.
            preferredOpenMode: .seizeIfNeeded,
            shouldEnumerateInterfaces: true
        )
    }
}
