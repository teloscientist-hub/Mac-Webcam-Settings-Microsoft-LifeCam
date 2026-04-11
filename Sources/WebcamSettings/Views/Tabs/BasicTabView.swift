import SwiftUI

struct BasicTabView: View {
    @ObservedObject var viewModel: BasicTabViewModel
    let inFlightControls: Set<CameraControlKey>
    let controlErrorMessages: [CameraControlKey: String]
    let onWrite: (CameraControlKey, CameraControlValue) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ControlSection(title: "Exposure") {
                    sectionRows(for: [.exposureMode, .exposureTime])
                }

                ControlSection(title: "Image") {
                    sectionRows(for: [.brightness, .contrast, .saturation, .sharpness])
                }

                ControlSection(title: "White Balance") {
                    sectionRows(for: [.whiteBalanceAuto, .whiteBalanceTemperature])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func sectionRows(for keys: [CameraControlKey]) -> some View {
        ForEach(keys, id: \.self) { key in
            if let capability = viewModel.capabilities.first(where: { $0.key == key }) {
                ControlRow(
                    capability: capability,
                    currentValues: viewModel.currentValues,
                    isWriting: inFlightControls.contains(capability.key),
                    errorMessage: controlErrorMessages[capability.key],
                    onWrite: onWrite
                )
            }
        }
    }
}
