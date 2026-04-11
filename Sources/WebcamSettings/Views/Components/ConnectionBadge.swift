import SwiftUI

struct ConnectionBadge: View {
    let state: AppViewModel.ConnectionState

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var label: String {
        switch state {
        case .loading: "Loading"
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        case .partialControlAccess: "Partial Access"
        }
    }

    private var color: Color {
        switch state {
        case .loading: .orange
        case .connected: .green
        case .disconnected: .secondary
        case .partialControlAccess: .yellow
        }
    }
}
