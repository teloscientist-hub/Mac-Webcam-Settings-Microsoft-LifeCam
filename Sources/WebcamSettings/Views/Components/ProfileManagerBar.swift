import SwiftUI

struct ProfileManagerBar: View {
    let profiles: [CameraProfile]
    @Binding var selectedProfileID: UUID?
    @Binding var draftName: String
    @Binding var loadAtStart: Bool
    let onSaveNew: () -> Void
    let onUpdate: () -> Void
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text("Profiles")
                .font(.headline)
            TextField("Profile name", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
            Picker(
                "Saved Profiles",
                selection: Binding(
                    get: { selectedProfileID },
                    set: { selectedProfileID = $0 }
                )
            ) {
                Text("None").tag(UUID?.none)
                ForEach(profiles) { profile in
                    Text(profile.name).tag(UUID?.some(profile.id))
                }
            }
            .frame(width: 220)
            Spacer()
            Toggle("Load at Start", isOn: $loadAtStart)
                .toggleStyle(.checkbox)
            Text("\(profiles.count) profile(s)")
                .foregroundStyle(.secondary)
            Button("Save New", action: onSaveNew)
            Button("Update", action: onUpdate)
                .disabled(selectedProfileID == nil)
            Button("Load", action: onLoad)
                .disabled(selectedProfileID == nil)
            Button("Delete", role: .destructive, action: onDelete)
                .disabled(selectedProfileID == nil)
        }
    }
}
