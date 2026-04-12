import Foundation
import Testing
@testable import WebcamSettings

private actor RecordingRawTransport: RawUVCTransporting {
    var lastPlan: RawUVCBindings.RequestPlan?
    var lastPayload: Data?
    let responsePayload: Data
    let responseProvider: (@Sendable (RawUVCBindings.RequestPlan) -> Data)?

    init(responsePayload: Data, responseProvider: (@Sendable (RawUVCBindings.RequestPlan) -> Data)? = nil) {
        self.responsePayload = responsePayload
        self.responseProvider = responseProvider
    }

    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        _ = device
        lastPlan = plan
        lastPayload = payload
        return responseProvider?(plan) ?? responsePayload
    }
}

private actor FailingRawTransport: RawUVCTransporting {
    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        _ = plan
        _ = payload
        _ = device
        throw CameraControlError.backendFailure("transport failed")
    }
}

private actor InvalidResponseLengthTransport: RawUVCTransporting {
    let responsePayload: Data

    init(responsePayload: Data) {
        self.responsePayload = responsePayload
    }

    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        _ = plan
        _ = payload
        _ = device
        return responsePayload
    }
}

private actor FlakyRawTransport: RawUVCTransporting {
    private var attempts = 0
    let responsePayload: Data
    let firstError: CameraControlError

    init(responsePayload: Data, firstError: CameraControlError = .timedOut) {
        self.responsePayload = responsePayload
        self.firstError = firstError
    }

    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        _ = plan
        _ = payload
        _ = device
        attempts += 1
        if attempts == 1 {
            throw firstError
        }
        return responsePayload
    }
}

private struct StubRawDeviceLocator: RawUVCDeviceLocating {
    let resolution: RawUVCDeviceResolution?

    func resolve(device: CameraDeviceDescriptor) async -> RawUVCDeviceResolution? {
        _ = device
        return resolution
    }
}

private actor RecordingRawControlTransferExecutor: RawUVCControlTransferExecuting {
    var lastTransfer: RawUVCControlTransfer.Plan?
    var lastPayload: Data?
    let responsePayload: Data

    init(responsePayload: Data) {
        self.responsePayload = responsePayload
    }

    func execute(transfer: RawUVCControlTransfer.Plan, payload: Data?) async throws -> Data {
        lastTransfer = transfer
        lastPayload = payload
        return responsePayload
    }
}

@Test
func validatingRawTransportRejectsUnexpectedWritePayloadLength() async throws {
    let debugStore = await MainActor.run { DebugStore() }
    let logger = AppLogger(subsystem: "Tests", category: "raw-transport")
    let validating = ValidatingRawUVCTransport(
        wrapped: RecordingRawTransport(responsePayload: Data()),
        logger: logger,
        debugStore: debugStore
    )
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .brightness, device: makeTransportDevice(), operation: .setCurrent)
    )

    do {
        _ = try await validating.execute(plan: plan, payload: Data([0x01]), device: makeTransportDevice())
        Issue.record("Expected write payload validation failure")
    } catch let error as CameraControlError {
        if case let .backendFailure(message) = error {
            #expect(message.contains("expected 2 payload bytes but got 1"))
        } else {
            Issue.record("Expected backend failure for invalid write payload length")
        }
    }

    let entries = await MainActor.run { debugStore.entries }
    #expect(entries.contains(where: { $0.category == "raw-transport" && $0.message.contains("Validation failure:") }))
}

@Test
func validatingRawTransportRejectsUnexpectedReadResponseLength() async throws {
    let debugStore = await MainActor.run { DebugStore() }
    let logger = AppLogger(subsystem: "Tests", category: "raw-transport")
    let validating = ValidatingRawUVCTransport(
        wrapped: InvalidResponseLengthTransport(responsePayload: Data([0x01])),
        logger: logger,
        debugStore: debugStore
    )
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .brightness, device: makeTransportDevice(), operation: .getCurrent)
    )

    do {
        _ = try await validating.execute(plan: plan, payload: nil, device: makeTransportDevice())
        Issue.record("Expected read response validation failure")
    } catch let error as CameraControlError {
        if case let .backendFailure(message) = error {
            #expect(message.contains("expected 2 response bytes but got 1"))
        } else {
            Issue.record("Expected backend failure for invalid read response length")
        }
    }

    let entries = await MainActor.run { debugStore.entries }
    #expect(entries.contains(where: { $0.category == "raw-transport" && $0.message.contains("Validation failure:") }))
}

@Test
func unavailableRawTransportIncludesResolvedTargetSummaryInFailure() async throws {
    let transport = UnavailableRawUVCTransport(
        locator: StubRawDeviceLocator(
            resolution: RawUVCDeviceResolution(
                manufacturer: "Microsoft",
                productName: "Microsoft LifeCam Studio",
                vendorID: 0x045E,
                productID: 0x0772,
                serialNumber: "ABC123",
                registryEntryID: 0x1234,
                serviceClassName: "IOUSBHostDevice"
            )
        ),
        executor: UnavailableRawUVCControlTransferExecutor()
    )
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .brightness, device: makeTransportDevice(), operation: .getCurrent)
    )

    do {
        _ = try await transport.execute(plan: plan, payload: Optional<Data>.none, device: makeTransportDevice())
        Issue.record("Expected unavailable transport failure")
    } catch let error as CameraControlError {
        if case let .backendFailure(message) = error {
            #expect(message.contains("target=[Microsoft, Microsoft LifeCam Studio, VID:PID 045E:0772, serial ABC123"))
            #expect(message.contains("deviceToHost req=0x81"))
        } else {
            Issue.record("Expected backend failure from unavailable transport")
        }
    }
}

@Test
func unavailableRawTransportBuildsTransferAndDelegatesToExecutor() async throws {
    let executor = RecordingRawControlTransferExecutor(responsePayload: Data([0x01]))
    let transport = UnavailableRawUVCTransport(
        locator: StubRawDeviceLocator(
            resolution: RawUVCDeviceResolution(
                manufacturer: "Microsoft",
                productName: "Microsoft LifeCam Studio",
                vendorID: 0x045E,
                productID: 0x0772,
                serialNumber: "ABC123",
                registryEntryID: 0x1234,
                serviceClassName: "IOUSBHostDevice"
            )
        ),
        executor: executor
    )
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .focusAuto, device: makeTransportDevice(), operation: .setCurrent)
    )

    let response = try await transport.execute(plan: plan, payload: Data([0x01]), device: makeTransportDevice())

    #expect(response == Data([0x01]))
    let transfer = await executor.lastTransfer
    #expect(transfer?.request == 0x01)
    #expect(transfer?.target.matchQuality == .exactSerial)
    let payload = await executor.lastPayload
    #expect(payload == Data([0x01]))
}

@Test
func syntheticRawBackendUsesTransportForWrites() async throws {
    let transport = RecordingRawTransport(responsePayload: Data())
    let backend = SyntheticRawUVCCameraBackend(transport: transport)
    let device = makeTransportDevice()

    try await backend.writeValue(.int(133), for: .brightness, device: device)

    let plan = await transport.lastPlan
    let payload = await transport.lastPayload
    #expect(plan?.operation == .setCurrent)
    #expect(plan?.key == .brightness)
    #expect(payload == Data([0x85, 0x00]))
}

@Test
func syntheticRawBackendUsesTransportForReads() async throws {
    let transport = RecordingRawTransport(
        responsePayload: Data(),
        responseProvider: { plan in
            switch plan.key {
            case .brightness:
                return Data([0x85, 0x00])
            case .exposureMode:
                return Data([0x08])
            case .exposureTime:
                return Data([0x4E, 0x00, 0x00, 0x00])
            case .focusAuto, .whiteBalanceAuto:
                return Data([0x01])
            case .focus, .zoom, .whiteBalanceTemperature, .backlightCompensation:
                return Data([0x01, 0x00])
            case .pan, .tilt:
                return Data([0x00, 0x00, 0x00, 0x00])
            case .contrast, .saturation, .sharpness:
                return Data([0x01, 0x00])
            case .powerLineFrequency:
                return Data([0x02])
            }
        }
    )
    let backend = SyntheticRawUVCCameraBackend(transport: transport)
    let device = makeTransportDevice()

    let values = try await backend.readCurrentValues(for: device)

    #expect(values[.brightness] == .int(133))
    let plan = await transport.lastPlan
    #expect(plan?.operation == .getCurrent)
}

@Test
func loggingRawTransportRecordsRequestAndResponseEntries() async throws {
    let transport = RecordingRawTransport(responsePayload: Data([0x01]))
    let debugStore = await MainActor.run { DebugStore() }
    let logger = AppLogger(subsystem: "Tests", category: "raw-transport")
    let loggingTransport = LoggingRawUVCTransport(
        wrapped: transport,
        logger: logger,
        debugStore: debugStore
    )
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .focusAuto, device: makeTransportDevice(), operation: .getCurrent)
    )

    _ = try await loggingTransport.execute(plan: plan, payload: nil, device: makeTransportDevice())

    let entries = await MainActor.run { debugStore.entries }
    #expect(entries.contains(where: { $0.category == "raw-transport" && $0.message.contains("Request:") }))
    #expect(entries.contains(where: { $0.category == "raw-transport" && $0.message.contains("Response:") }))
}

@Test
func loggingRawTransportRecordsFailures() async {
    let debugStore = await MainActor.run { DebugStore() }
    let logger = AppLogger(subsystem: "Tests", category: "raw-transport")
    let loggingTransport = LoggingRawUVCTransport(
        wrapped: FailingRawTransport(),
        logger: logger,
        debugStore: debugStore
    )
    let plan = RawUVCBindings.requestPlan(for: .focusAuto, device: makeTransportDevice(), operation: .getCurrent)!

    do {
        _ = try await loggingTransport.execute(plan: plan, payload: nil, device: makeTransportDevice())
        Issue.record("Expected logging transport failure")
    } catch {
        let entries = await MainActor.run { debugStore.entries }
        #expect(entries.contains(where: { $0.category == "raw-transport" && $0.message.contains("Failure:") }))
    }
}

@Test
func retryingRawTransportRetriesTimedOutRequests() async throws {
    let flaky = FlakyRawTransport(responsePayload: Data([0x01]))
    let debugStore = await MainActor.run { DebugStore() }
    let logger = AppLogger(subsystem: "Tests", category: "raw-transport")
    let retrying = RetryingRawUVCTransport(
        wrapped: flaky,
        maxAttempts: 2,
        retryDelayNanoseconds: 1_000,
        logger: logger,
        debugStore: debugStore
    )
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .focusAuto, device: makeTransportDevice(), operation: .getCurrent)
    )

    let response = try await retrying.execute(plan: plan, payload: nil, device: makeTransportDevice())

    #expect(response == Data([0x01]))
    let entries = await MainActor.run { debugStore.entries }
    #expect(entries.contains(where: { $0.category == "raw-transport" && $0.message.contains("Retrying raw UVC") }))
}

@Test
func validatingRawTransportRejectsUnexpectedReadRequestPayload() async throws {
    let debugStore = await MainActor.run { DebugStore() }
    let logger = AppLogger(subsystem: "Tests", category: "raw-transport")
    let validating = ValidatingRawUVCTransport(
        wrapped: RecordingRawTransport(responsePayload: Data([0x01])),
        logger: logger,
        debugStore: debugStore
    )
    let plan = try #require(
        RawUVCBindings.requestPlan(for: .focusAuto, device: makeTransportDevice(), operation: .getCurrent)
    )

    do {
        _ = try await validating.execute(plan: plan, payload: Data([0x01]), device: makeTransportDevice())
        Issue.record("Expected read request payload validation failure")
    } catch let error as CameraControlError {
        if case let .backendFailure(message) = error {
            #expect(message.contains("should not include a payload"))
        } else {
            Issue.record("Expected backend failure for invalid read request payload")
        }
    }

    let entries = await MainActor.run { debugStore.entries }
    #expect(entries.contains(where: { $0.category == "raw-transport" && $0.message.contains("Validation failure:") }))
}

@Test
func policyRawTransportRetriesReadsButNotWritesByDefault() async throws {
    let debugStore = await MainActor.run { DebugStore() }
    let logger = AppLogger(subsystem: "Tests", category: "raw-transport")
    let readTransport = PolicyRawUVCTransport(
        wrapped: FlakyRawTransport(responsePayload: Data([0x01]), firstError: .timedOut),
        policy: .default,
        logger: logger,
        debugStore: debugStore
    )
    let readPlan = try #require(
        RawUVCBindings.requestPlan(for: .focusAuto, device: makeTransportDevice(), operation: .getCurrent)
    )

    let readResponse = try await readTransport.execute(plan: readPlan, payload: nil, device: makeTransportDevice())
    #expect(readResponse == Data([0x01]))

    let writeTransport = PolicyRawUVCTransport(
        wrapped: FlakyRawTransport(responsePayload: Data(), firstError: .timedOut),
        policy: .default,
        logger: logger,
        debugStore: debugStore
    )
    let writePlan = try #require(
        RawUVCBindings.requestPlan(for: .focusAuto, device: makeTransportDevice(), operation: .setCurrent)
    )

    do {
        _ = try await writeTransport.execute(plan: writePlan, payload: Data([0x01]), device: makeTransportDevice())
        Issue.record("Expected write transport to stop after first timeout with default policy")
    } catch let error as CameraControlError {
        #expect(error == .timedOut)
    }
}

private func makeTransportDevice() -> CameraDeviceDescriptor {
    CameraDeviceDescriptor(
        id: "transport-cam-1",
        name: "Microsoft LifeCam Studio",
        manufacturer: "Microsoft",
        model: "LifeCam Studio",
        vendorID: 0x045E,
        productID: 0x0772,
        serialNumber: "ABC123",
        transportType: .usb,
        isConnected: true,
        avFoundationUniqueID: "avf-transport-1",
        backendIdentifier: "backend-transport-1"
    )
}
