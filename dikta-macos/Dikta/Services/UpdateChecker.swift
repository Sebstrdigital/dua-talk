import Foundation
import AppKit

/// Checks GitHub releases for newer versions
@MainActor
final class UpdateChecker: ObservableObject {
    @Published var availableVersion: String?

    private static let releasesAPI = "https://api.github.com/repos/Sebstrdigital/dikta/releases/latest"
    private static let releasesPage = "https://github.com/Sebstrdigital/dikta/releases/latest"

    func check() {
        guard let url = URL(string: Self.releasesAPI) else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String else { return }

                let remote = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let local = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

                if remote.compare(local, options: .numeric) == .orderedDescending {
                    availableVersion = remote
                }
            } catch {
                // Silently ignore — offline or rate-limited
            }
        }
    }

    func openReleasesPage() {
        if let url = URL(string: Self.releasesPage) {
            NSWorkspace.shared.open(url)
        }
    }
}
