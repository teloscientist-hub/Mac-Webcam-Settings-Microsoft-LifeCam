import Foundation

#if canImport(IOKit)
import IOKit

struct RawUVCResolvedIOKitService: Sendable, Equatable {
    let registryEntryID: UInt64
    let serviceClassName: String?
}

protocol RawUVCIOKitServiceResolving: Sendable {
    func resolveService(for target: RawUVCTransportTarget) throws -> RawUVCResolvedIOKitService
}

struct DefaultRawUVCIOKitServiceResolver: RawUVCIOKitServiceResolving {
    func resolveService(for target: RawUVCTransportTarget) throws -> RawUVCResolvedIOKitService {
        guard let registryEntryID = target.registryEntryID else {
            throw CameraControlError.backendFailure(
                "No registry entry ID is available for \(target.summary)."
            )
        }

        guard let matching = IORegistryEntryIDMatching(registryEntryID) else {
            throw CameraControlError.backendFailure(
                "Failed to build an IOKit matching dictionary for \(target.summary)."
            )
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            throw CameraControlError.backendFailure(
                "No IOKit service was found for registry entry 0x\(String(format: "%016llX", registryEntryID))."
            )
        }

        defer { IOObjectRelease(service) }

        if let expectedClass = target.serviceClassName,
           IOObjectConformsTo(service, expectedClass) == 0 {
            throw CameraControlError.backendFailure(
                "Resolved registry entry 0x\(String(format: "%016llX", registryEntryID)) but it does not conform to \(expectedClass)."
            )
        }

        return RawUVCResolvedIOKitService(
            registryEntryID: registryEntryID,
            serviceClassName: target.serviceClassName
        )
    }
}
#endif
