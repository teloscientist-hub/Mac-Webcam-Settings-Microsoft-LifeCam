import Foundation
import Testing
@testable import WebcamSettings

#if canImport(IOKit)
private struct StubRawUVCIOKitServiceResolver: RawUVCIOKitServiceResolving {
    let result: Result<RawUVCResolvedIOKitService, Error>

    func resolveService(for target: RawUVCTransportTarget) throws -> RawUVCResolvedIOKitService {
        _ = target
        return try result.get()
    }
}

private struct StubRawUVCDeviceInterfaceOpener: RawUVCDeviceInterfaceOpening {
    let result: Result<RawUVCOpenedDeviceInterface, Error>

    func open(plan: RawUVCDeviceInterfacePlan) throws -> RawUVCOpenedDeviceInterface {
        _ = plan
        return try result.get()
    }
}

@Test
func ioKitExecutorIncludesResolvedContextWhenControlRequestCannotStart() async throws {
    let executor = IOKitRawUVCControlTransferExecutor(
        serviceResolver: StubRawUVCIOKitServiceResolver(
            result: .success(
                RawUVCResolvedIOKitService(
                    registryEntryID: 0x1234,
                    serviceClassName: "IOUSBHostDevice"
                )
            )
        ),
        deviceInterfaceOpener: StubRawUVCDeviceInterfaceOpener(
            result: .success(
                RawUVCOpenedDeviceInterface(
                    registryEntryID: 0x1234,
                    configurationCount: 1,
                    interfaces: [
                        RawUVCEnumeratedInterface(
                            registryEntryID: 0x4321,
                            interfaceNumber: 0,
                            alternateSetting: 0,
                            interfaceClass: 0x0E,
                            interfaceSubClass: 0x01,
                            interfaceProtocol: 0x00,
                            endpointCount: 1
                        )
                    ],
                    controlInterface: RawUVCEnumeratedInterface(
                        registryEntryID: 0x4321,
                        interfaceNumber: 0,
                        alternateSetting: 0,
                        interfaceClass: 0x0E,
                        interfaceSubClass: 0x01,
                        interfaceProtocol: 0x00,
                        endpointCount: 1
                    )
                )
            )
        )
    )
    let transfer = RawUVCControlTransfer.plan(
        for: try #require(
            RawUVCBindings.requestPlan(for: .brightness, device: makeExecutorDevice(), operation: .getCurrent)
        ),
        target: try #require(
            RawUVCDeviceLocatorSupport.makeTransportTarget(
                for: makeExecutorDevice(),
                resolution: RawUVCDeviceResolution(
                    manufacturer: "Microsoft",
                    productName: "Microsoft LifeCam Studio",
                    vendorID: 0x045E,
                    productID: 0x0772,
                    serialNumber: "ABC123",
                    registryEntryID: 0x1234,
                    serviceClassName: "IOUSBHostDevice"
                )
            )
        )
    )

    do {
        _ = try await executor.execute(transfer: transfer, payload: nil)
        Issue.record("Expected IOKit executor to stop after resolution")
    } catch let error as CameraControlError {
        if case let .backendFailure(message) = error {
            #expect(message.contains("for Microsoft, Microsoft LifeCam Studio"))
            #expect(message.contains("interface plan: seizeIfNeeded"))
            #expect(message.contains("deviceInterface=kIOUSBDeviceInterfaceID942"))
            #expect(message.contains("selected control interface: if=0 alt=0 class=0x0E subclass=0x01"))
            #expect(message.contains("Could not reacquire the selected control interface service"))
        } else {
            Issue.record("Expected backend failure from IOKit executor")
        }
    }
}

@Test
func ioKitExecutorPropagatesResolverFailures() async throws {
    let executor = IOKitRawUVCControlTransferExecutor(
        serviceResolver: StubRawUVCIOKitServiceResolver(
            result: .failure(CameraControlError.backendFailure("No IOKit service was found"))
        ),
        deviceInterfaceOpener: StubRawUVCDeviceInterfaceOpener(
            result: .success(
                RawUVCOpenedDeviceInterface(
                    registryEntryID: 0x1234,
                    configurationCount: 1,
                    interfaces: [],
                    controlInterface: nil
                )
            )
        )
    )
    let transfer = RawUVCControlTransfer.plan(
        for: try #require(
            RawUVCBindings.requestPlan(for: .brightness, device: makeExecutorDevice(), operation: .getCurrent)
        ),
        target: try #require(
            RawUVCDeviceLocatorSupport.makeTransportTarget(for: makeExecutorDevice(), resolution: nil)
        )
    )

    do {
        _ = try await executor.execute(transfer: transfer, payload: nil)
        Issue.record("Expected resolver failure to propagate")
    } catch let error as CameraControlError {
        #expect(error == .backendFailure("No IOKit service was found"))
    }
}

private func makeExecutorDevice() -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "executor-cam-1",
        name: "Microsoft LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: nil,
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-executor-1",
        backendIdentifier: "backend-executor-1"
    )
}
#endif
