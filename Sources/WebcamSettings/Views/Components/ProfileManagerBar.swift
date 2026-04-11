import SwiftUI

struct ProfileManagerBar: View {
    let profiles: [CameraProfile]

    var body: some View {
        HStack {
            Text("Profiles")
                .font(.headline)
            Spacer()
            if profiles.isEmpty {
                Text("No saved profiles yet")
                    .foregroundStyle(.secondary)
            } else {
                Text("\(profiles.count) profile(s)")
                    .foregroundStyle(.secondary)
            }
            Button("Save") {}
            Button("Load") {}
            Button("Delete") {}
        }
    }
}
