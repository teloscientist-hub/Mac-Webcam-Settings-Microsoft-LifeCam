import SwiftUI

@MainActor
struct EnumSelectorRow: View {
    let title: String
    let options: [CameraControlOption]
    let selectedValue: String
    let isEnabled: Bool
    let helperText: String?
    let onChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.subheadline)
                    .frame(width: 145, alignment: .leading)
                Spacer(minLength: 0)
                Picker(
                    title,
                    selection: Binding(
                        get: { selectedValue },
                        set: { newValue in onChange(newValue) }
                    )
                ) {
                    ForEach(options) { option in
                        Text(option.title).tag(option.value)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
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
