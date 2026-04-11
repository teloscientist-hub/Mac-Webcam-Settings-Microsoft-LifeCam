import SwiftUI

@MainActor
struct ToggleControlRow: View {
    let title: String
    let isOn: Bool
    let isEnabled: Bool
    let helperText: String?
    let onChange: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                title,
                isOn: Binding(
                    get: { isOn },
                    set: { newValue in onChange(newValue) }
                )
            )
            .disabled(!isEnabled)

            if let helperText {
                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}
