import Foundation

actor CameraControlActor {
    func execute<T>(_ work: @Sendable () async throws -> T) async throws -> T {
        try await work()
    }
}
