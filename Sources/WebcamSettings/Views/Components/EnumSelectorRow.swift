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
            HStack {
                Text(title)
                Spacer()
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
                .frame(width: 180)
                .disabled(!isEnabled)
            }

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
