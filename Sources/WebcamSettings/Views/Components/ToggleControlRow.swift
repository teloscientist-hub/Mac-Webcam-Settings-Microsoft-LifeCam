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
            HStack(spacing: 10) {
                Text(title)
                    .font(.subheadline)
                    .frame(width: 145, alignment: .leading)
                Spacer(minLength: 0)
                Toggle(
                    "",
                    isOn: Binding(
                        get: { isOn },
                        set: { newValue in onChange(newValue) }
                    )
                )
                .labelsHidden()
                .disabled(!isEnabled)
            }

            if let helperText {
                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 155)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}
