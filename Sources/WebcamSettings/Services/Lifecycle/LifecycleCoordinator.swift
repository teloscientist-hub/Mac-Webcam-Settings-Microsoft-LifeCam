import Foundation

actor LifecycleCoordinator {
    private let logger: AppLogger
    private let debugStore: DebugStore

    init(logger: AppLogger, debugStore: DebugStore) {
        self.logger = logger
        self.debugStore = debugStore
    }

    func start() async {
        logger.debug("Lifecycle coordinator scaffold started")
        await debugStore.record(category: "lifecycle", message: "Lifecycle coordinator scaffold started")
    }
}
