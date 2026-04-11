import AppKit
import Foundation

actor LifecycleCoordinator {
    enum Event: Sendable {
        case willSleep
        case didWake
    }

    private let logger: AppLogger
    private let debugStore: DebugStore
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]
    private var tasks: [Task<Void, Never>] = []

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
    }

    func start() async {
        guard tasks.isEmpty else { return }

        let notificationCenter = NSWorkspace.shared.notificationCenter
        tasks = [
            Task { [weak self] in
                guard let self else { return }
                for await _ in notificationCenter.notifications(named: NSWorkspace.willSleepNotification) {
                    await self.broadcast(.willSleep, message: "System entering sleep")
                }
            },
            Task { [weak self] in
                guard let self else { return }
                for await _ in notificationCenter.notifications(named: NSWorkspace.didWakeNotification) {
                    await self.broadcast(.didWake, message: "System woke from sleep")
                }
            }
        ]

        logger.debug("Lifecycle coordinator active")
        await debugStore.record(category: "lifecycle", message: "Lifecycle coordinator active")
    }

    func events() async -> AsyncStream<Event> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.removeContinuation(id)
                }
            }
        }
    }

    private func broadcast(_ event: Event, message: String) async {
        logger.info(message)
        await debugStore.record(category: "lifecycle", message: message)
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
