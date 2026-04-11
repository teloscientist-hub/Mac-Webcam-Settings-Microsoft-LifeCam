import Foundation

@MainActor
final class DebugStore: ObservableObject {
    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let category: String
        let message: String
    }

    @Published private(set) var entries: [Entry] = []

    func record(category: String, message: String) {
        entries.insert(Entry(timestamp: .now, category: category, message: message), at: 0)
        if entries.count > 300 {
            entries = Array(entries.prefix(300))
        }
    }
}
