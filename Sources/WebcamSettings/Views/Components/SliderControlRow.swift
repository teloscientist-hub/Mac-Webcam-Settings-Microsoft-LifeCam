import SwiftUI

@MainActor
struct SliderControlRow: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let prefersIntegerInput: Bool
    let isEnabled: Bool
    let helperText: String?
    let onChange: (Double) -> Void

    @State private var usesNumericInput = false
    @State private var draftValue = ""
    @State private var numericFieldIsFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.subheadline)
                    .frame(width: 145, alignment: .leading)

                if usesNumericInput {
                    NumericEntryField(
                        text: $draftValue,
                        isFocused: $numericFieldIsFocused,
                        isEnabled: isEnabled,
                        onCommit: {
                            commitDraftValue()
                        },
                        onIncrement: {
                            nudgeDraftValue(by: prefersIntegerInput ? 1 : step)
                        },
                        onDecrement: {
                            nudgeDraftValue(by: prefersIntegerInput ? -1 : -step)
                        }
                    )
                    .frame(width: 84)
                } else {
                    Slider(
                        value: Binding(
                            get: { value },
                            set: { newValue in onChange(newValue) }
                        ),
                        in: range,
                        step: step
                    )
                    .disabled(!isEnabled)
                }

                Button {
                    usesNumericInput.toggle()
                    draftValue = formattedValue
                } label: {
                    Text("#")
                        .font(.caption.weight(.semibold))
                        .monospaced()
                        .foregroundStyle(usesNumericInput ? .primary : .secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.quaternary.opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)

                Text(formattedValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }

            if usesNumericInput {
                Text("Press Return to apply")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 155)
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
        .onAppear {
            draftValue = formattedValue
        }
        .onChange(of: value) { _, _ in
            draftValue = formattedValue
        }
        .onChange(of: usesNumericInput) { _, newValue in
            numericFieldIsFocused = newValue
        }
    }

    private var formattedValue: String {
        if prefersIntegerInput {
            return Int(value.rounded()).formatted()
        }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    private func commitDraftValue() {
        guard let parsedValue = parseDraftValue(draftValue) else {
            draftValue = formattedValue
            return
        }

        let clampedValue = min(max(parsedValue, range.lowerBound), range.upperBound)
        let resolvedValue: Double
        if prefersIntegerInput {
            resolvedValue = clampedValue.rounded()
        } else {
            let steps = ((clampedValue - range.lowerBound) / step).rounded()
            resolvedValue = range.lowerBound + (steps * step)
        }

        draftValue = prefersIntegerInput
            ? Int(resolvedValue).formatted()
            : resolvedValue.formatted(.number.precision(.fractionLength(2)))
        numericFieldIsFocused = true
        onChange(resolvedValue)
    }

    private func nudgeDraftValue(by delta: Double) {
        let currentDraft = parseDraftValue(draftValue) ?? value
        let adjustedValue = currentDraft + delta
        let clampedValue = min(max(adjustedValue, range.lowerBound), range.upperBound)
        let resolvedValue = prefersIntegerInput ? clampedValue.rounded() : clampedValue
        draftValue = prefersIntegerInput
            ? Int(resolvedValue).formatted()
            : resolvedValue.formatted(.number.precision(.fractionLength(2)))
        numericFieldIsFocused = true
        onChange(resolvedValue)
    }

    private func parseDraftValue(_ rawValue: String) -> Double? {
        let groupingSeparator = Locale.current.groupingSeparator ?? ","
        let decimalSeparator = Locale.current.decimalSeparator ?? "."

        let normalized = rawValue
            .replacingOccurrences(of: groupingSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(normalized)
    }
}
