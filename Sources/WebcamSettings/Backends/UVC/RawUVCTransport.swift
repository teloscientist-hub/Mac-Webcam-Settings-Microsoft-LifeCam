import Foundation

protocol RawUVCTransporting: Sendable {
    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data
}

struct RawUVCTransportPolicy: Sendable, Equatable {
    let readAttempts: Int
    let writeAttempts: Int
    let retryDelayNanoseconds: UInt64

    static let `default` = RawUVCTransportPolicy(
        readAttempts: 2,
        writeAttempts: 1,
        retryDelayNanoseconds: 50_000_000
    )
}

actor ValidatingRawUVCTransport: RawUVCTransporting {
    private let wrapped: any RawUVCTransporting
    private let logger: AppLogger?
    private let debugStore: DebugStore?

    init(
        wrapped: any RawUVCTransporting,
        logger: AppLogger? = nil,
        debugStore: DebugStore? = nil
    ) {
        self.wrapped = wrapped
        self.logger = logger
        self.debugStore = debugStore
    }

    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        try await validateRequest(plan: plan, payload: payload, device: device)
        let response = try await wrapped.execute(plan: plan, payload: payload, device: device)
        try await validateResponse(response, for: plan, device: device)
        return response
    }

    private func validateRequest(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws {
        switch plan.operation {
        case .getCurrent:
            guard payload == nil || payload?.isEmpty == true else {
                try await failValidation(
                    "Raw UVC getCurrent for \(plan.key.displayName) should not include a payload (got \(payload?.count ?? 0) bytes).",
                    device: device
                )
            }
        case .setCurrent:
            guard let payload else {
                try await failValidation(
                    "Raw UVC setCurrent for \(plan.key.displayName) is missing its payload.",
                    device: device
                )
            }

            guard payload.count == plan.expectedLength else {
                try await failValidation(
                    "Raw UVC setCurrent for \(plan.key.displayName) expected \(plan.expectedLength) payload bytes but got \(payload.count).",
                    device: device
                )
            }
        }
    }

    private func validateResponse(
        _ response: Data,
        for plan: RawUVCBindings.RequestPlan,
        device: CameraDeviceDescriptor
    ) async throws {
        switch plan.operation {
        case .getCurrent:
            guard response.count == plan.expectedLength else {
                try await failValidation(
                    "Raw UVC getCurrent for \(plan.key.displayName) expected \(plan.expectedLength) response bytes but got \(response.count).",
                    device: device
                )
            }
        case .setCurrent:
            guard response.isEmpty || response.count == plan.expectedLength else {
                try await failValidation(
                    "Raw UVC setCurrent for \(plan.key.displayName) expected an empty acknowledgment or \(plan.expectedLength) response bytes but got \(response.count).",
                    device: device
                )
            }
        }
    }

    private func failValidation(_ message: String, device: CameraDeviceDescriptor) async throws -> Never {
        let fullMessage = "\(message) Device: \(device.name)."
        logger?.error(fullMessage)
        await debugStore?.record(category: "raw-transport", message: "Validation failure: \(fullMessage)")
        throw CameraControlError.backendFailure(fullMessage)
    }
}

actor PolicyRawUVCTransport: RawUVCTransporting {
    private let wrapped: any RawUVCTransporting
    private let policy: RawUVCTransportPolicy
    private let logger: AppLogger?
    private let debugStore: DebugStore?

    init(
        wrapped: any RawUVCTransporting,
        policy: RawUVCTransportPolicy = .default,
        logger: AppLogger? = nil,
        debugStore: DebugStore? = nil
    ) {
        self.wrapped = wrapped
        self.policy = policy
        self.logger = logger
        self.debugStore = debugStore
    }

    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        let maxAttempts = switch plan.operation {
        case .getCurrent: max(1, policy.readAttempts)
        case .setCurrent: max(1, policy.writeAttempts)
        }

        var attempt = 1
        while true {
            do {
                return try await wrapped.execute(plan: plan, payload: payload, device: device)
            } catch {
                guard shouldRetry(error), attempt < maxAttempts else {
                    throw error
                }

                let message = "Retrying raw UVC \(plan.operation.rawValue) for \(plan.key.displayName) after error: \(error.localizedDescription)"
                logger?.debug(message)
                await debugStore?.record(category: "raw-transport", message: message)
                attempt += 1
                try? await Task.sleep(nanoseconds: policy.retryDelayNanoseconds)
            }
        }
    }

    private func shouldRetry(_ error: Error) -> Bool {
        guard let controlError = error as? CameraControlError else {
            return false
        }

        switch controlError {
        case .deviceBusy, .timedOut:
            return true
        default:
            return false
        }
    }
}

actor RetryingRawUVCTransport: RawUVCTransporting {
    private let wrapped: any RawUVCTransporting
    private let maxAttempts: Int
    private let retryDelayNanoseconds: UInt64
    private let logger: AppLogger?
    private let debugStore: DebugStore?

    init(
        wrapped: any RawUVCTransporting,
        maxAttempts: Int = 2,
        retryDelayNanoseconds: UInt64 = 50_000_000,
        logger: AppLogger? = nil,
        debugStore: DebugStore? = nil
    ) {
        self.wrapped = wrapped
        self.maxAttempts = max(1, maxAttempts)
        self.retryDelayNanoseconds = retryDelayNanoseconds
        self.logger = logger
        self.debugStore = debugStore
    }

    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        var attempt = 1
        while true {
            do {
                return try await wrapped.execute(plan: plan, payload: payload, device: device)
            } catch {
                guard shouldRetry(error), attempt < maxAttempts else {
                    throw error
                }

                let message = "Retrying raw UVC \(plan.operation.rawValue) for \(plan.key.displayName) after error: \(error.localizedDescription)"
                logger?.debug(message)
                await debugStore?.record(category: "raw-transport", message: message)
                attempt += 1
                try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
        }
    }

    private func shouldRetry(_ error: Error) -> Bool {
        guard let controlError = error as? CameraControlError else {
            return false
        }

        switch controlError {
        case .deviceBusy, .timedOut:
            return true
        default:
            return false
        }
    }
}

actor LoggingRawUVCTransport: RawUVCTransporting {
    private let wrapped: any RawUVCTransporting
    private let logger: AppLogger?
    private let debugStore: DebugStore?

    init(
        wrapped: any RawUVCTransporting,
        logger: AppLogger? = nil,
        debugStore: DebugStore? = nil
    ) {
        self.wrapped = wrapped
        self.logger = logger
        self.debugStore = debugStore
    }

    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        let requestSummary = summary(for: plan, payload: payload, device: device)
        logger?.debug("Raw UVC request: \(requestSummary)")
        await debugStore?.record(category: "raw-transport", message: "Request: \(requestSummary)")

        do {
            let response = try await wrapped.execute(plan: plan, payload: payload, device: device)
            let responseSummary = "selector=0x\(String(format: "%02X", plan.selector)) len=\(response.count)"
            logger?.debug("Raw UVC response: \(responseSummary)")
            await debugStore?.record(category: "raw-transport", message: "Response: \(responseSummary)")
            return response
        } catch {
            logger?.error("Raw UVC transport failed: \(error.localizedDescription)")
            await debugStore?.record(category: "raw-transport", message: "Failure: \(error.localizedDescription)")
            throw error
        }
    }

    private func summary(
        for plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) -> String {
        let payloadSummary = payload.map { data in
            data.map { String(format: "%02X", $0) }.joined(separator: " ")
        } ?? "none"

        return "\(device.name) \(plan.operation.rawValue) entity=\(plan.entity.rawValue) selector=0x\(String(format: "%02X", plan.selector)) unit=\(plan.unitID) len=\(plan.expectedLength) payload=[\(payloadSummary)]"
    }
}

actor UnavailableRawUVCTransport: RawUVCTransporting {
    private let locator: any RawUVCDeviceLocating
    private let executor: any RawUVCControlTransferExecuting

    init(
        locator: any RawUVCDeviceLocating = RegistryRawUVCDeviceLocator(),
        executor: any RawUVCControlTransferExecuting = UnavailableRawUVCControlTransferExecutor()
    ) {
        self.locator = locator
        self.executor = executor
    }

    func execute(
        plan: RawUVCBindings.RequestPlan,
        payload: Data?,
        device: CameraDeviceDescriptor
    ) async throws -> Data {
        let resolution = await locator.resolve(device: device)
        let target = RawUVCDeviceLocatorSupport.makeTransportTarget(for: device, resolution: resolution)
        guard let target else {
            throw CameraControlError.backendFailure(
                "Raw UVC transport could not resolve a USB target for \(device.name) (\(plan.operation.rawValue), entity \(plan.entity.rawValue), selector 0x\(String(format: "%02X", plan.selector)), unit \(plan.unitID), len \(plan.expectedLength))."
            )
        }

        let transfer = RawUVCControlTransfer.plan(for: plan, target: target)
        do {
            return try await executor.execute(transfer: transfer, payload: payload)
        } catch let error as CameraControlError {
            throw error
        } catch {
            throw CameraControlError.backendFailure(error.localizedDescription)
        }
    }
}
