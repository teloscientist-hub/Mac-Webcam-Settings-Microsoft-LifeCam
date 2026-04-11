import SwiftUI

struct StatusBanner: View {
    let message: String
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message)
                .font(.subheadline.weight(.medium))
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
