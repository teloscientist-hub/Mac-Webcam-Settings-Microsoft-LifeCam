import Foundation
import Testing
@testable import WebcamSettings

actor ProfileApplyMockControlService: CameraControlServicing {
    let capabilities: [CameraControlCapability]
    private(set) var writes: [(CameraControlKey, CameraControlValue)] = []

    init(capabilities: [CameraControlCapability]) {
        self.capabilities = capabilities
    }

    func fetchCapabilities(for device: CameraDeviceDescriptor) async throws -> [CameraControlCapability] {
        _ = device
        return capabilities
    }

    func readCurrentValues(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        _ = device
        return [:]
    }

    func writeValue(_ value: CameraControlValue, for key: CameraControlKey, device: CameraDeviceDescriptor) async throws {
        _ = device
        writes.append((key, value))
    }

    func refreshCurrentState(for device: CameraDeviceDescriptor) async throws -> [CameraControlKey: CameraControlValue] {
        _ = device
        return [:]
    }
}

@Test
func profileApplySkipsUnsupportedControlsInsteadOfFailing() async {
    let supportedBrightness = CameraControlCapability(
        key: .brightness,
        displayName: "Brightness",
        type: .integerRange,
        isSupported: true,
        isReadable: true,
        isWritable: true,
        minValue: .int(0),
        maxValue: .int(100),
        stepValue: .int(1),
        defaultValue: .int(50),
        currentValue: .int(50),
        enumOptions: [],
        dependency: nil
    )
    let unsupportedPan = CameraControlCapability(
        key: .pan,
        displayName: "Pan",
        type: .integerRange,
        isSupported: false,
        isReadable: false,
        isWritable: false,
        minValue: .int(0),
        maxValue: .int(100),
        stepValue: .int(1),
        defaultValue: .int(50),
        currentValue: nil,
        enumOptions: [],
        dependency: nil
    )
    let controlService = ProfileApplyMockControlService(capabilities: [supportedBrightness, unsupportedPan])
    let writeCoordinator = ControlWriteCoordinator(
        controlService: controlService,
        logger: AppLogger(subsystem: "Tests", category: "profiles"),
        debugStore: await MainActor.run { DebugStore() }
    )
    let coordinator = ProfileApplyCoordinator(
        controlService: controlService,
        writeCoordinator: writeCoordinator,
        logger: AppLogger(subsystem: "Tests", category: "profiles"),
        debugStore: await MainActor.run { DebugStore() }
    )
    let profile = CameraProfile(
        name: "Mixed Support",
        deviceMatch: ProfileDeviceMatch(
            deviceName: "Generic Cam",
            deviceIdentifier: "cam-1",
            manufacturer: nil,
            model: nil,
            vendorID: nil,
            productID: nil,
            serialNumber: nil
        ),
        values: [
            .brightness: .int(40),
            .pan: .int(10)
        ]
    )

    let result = await coordinator.apply(profile: profile, to: makeApplyDevice())

    #expect(result.succeededCount == 1)
    #expect(result.skippedCount == 1)
    #expect(result.items.first(where: { $0.key == .pan })?.status == .skippedUnsupported)
    let writes = await controlService.writes
    #expect(writes.count == 1)
    #expect(writes.first?.0 == .brightness)
}

private func makeApplyDevice() -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "cam-1",
        name: "Generic Cam",
        manufacturer: nil,
        model: nil,
        vendorID: nil,
        productID: nil,
        serialNumber: nil,
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-1",
        backendIdentifier: "backend-1"
    )
}
