import SwiftUI

@MainActor
struct SliderControlRow: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let isEnabled: Bool
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { value },
                    set: { newValue in onChange(newValue) }
                ),
                in: range
            )
                .disabled(!isEnabled)
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}
