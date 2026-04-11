import SwiftUI

struct AdvancedTabView: View {
    @ObservedObject var viewModel: AdvancedTabViewModel
    let onWrite: (CameraControlKey, CameraControlValue) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.capabilities) { capability in
                    ControlRow(capability: capability, currentValue: viewModel.currentValues[capability.key], onWrite: onWrite)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
