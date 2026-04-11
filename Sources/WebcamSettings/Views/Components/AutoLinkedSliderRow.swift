import SwiftUI

@MainActor
struct AutoLinkedSliderRow: View {
    let toggleTitle: String
    let sliderTitle: String
    let isAutomatic: Bool
    let sliderValue: Double
    let range: ClosedRange<Double>
    let onToggle: (Bool) -> Void
    let onSlide: (Double) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Toggle(
                toggleTitle,
                isOn: Binding(
                    get: { isAutomatic },
                    set: { newValue in onToggle(newValue) }
                )
            )
            SliderControlRow(
                title: sliderTitle,
                value: sliderValue,
                range: range,
                isEnabled: !isAutomatic,
                helperText: nil,
                onChange: onSlide
            )
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}
