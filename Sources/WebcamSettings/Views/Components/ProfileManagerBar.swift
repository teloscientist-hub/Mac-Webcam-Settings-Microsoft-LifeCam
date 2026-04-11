import SwiftUI

struct ProfileManagerBar: View {
    let profiles: [CameraProfile]
    @Binding var selectedProfileID: UUID?
    @Binding var draftName: String
    @Binding var loadAtStart: Bool
    let matchDescription: String
    let canUpdate: Bool
    let canLoad: Bool
    let onSaveNew: () -> Void
    let onUpdate: () -> Void
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Profiles")
                    .font(.headline)
                Spacer()
                Text(matchDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
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
                    .disabled(!canUpdate)
                Button("Load", action: onLoad)
                    .disabled(!canLoad)
                Button("Delete", role: .destructive, action: onDelete)
                    .disabled(selectedProfileID == nil)
            }
        }
    }
}
