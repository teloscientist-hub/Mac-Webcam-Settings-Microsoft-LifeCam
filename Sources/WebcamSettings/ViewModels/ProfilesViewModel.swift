import Foundation

@MainActor
final class ProfilesViewModel: ObservableObject {
    @Published var profiles: [CameraProfile] = []
}
