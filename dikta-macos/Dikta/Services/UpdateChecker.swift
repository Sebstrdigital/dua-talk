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

                let remote = Self.normalizeTag(tag)
                let local = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

                if Self.isNewer(remote: remote, than: local) {
                    availableVersion = remote
                }
            } catch {
                // Silently ignore — offline or rate-limited
            }
        }
    }

    /// Strip leading 'v'/'V' from a GitHub tag name
    static func normalizeTag(_ tag: String) -> String {
        tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    /// Returns true if `remote` is a newer version than `local` using numeric comparison.
    /// Malformed versions that can't be compared numerically return false.
    static func isNewer(remote: String, than local: String) -> Bool {
        // Ensure both strings contain only numeric version components (e.g. "0.4.1")
        let validPattern = #"^\d+(\.\d+)*$"#
        guard remote.range(of: validPattern, options: .regularExpression) != nil,
              local.range(of: validPattern, options: .regularExpression) != nil else {
            return false
        }
        return remote.compare(local, options: .numeric) == .orderedDescending
    }

    func openReleasesPage() {
        if let url = URL(string: Self.releasesPage) {
            NSWorkspace.shared.open(url)
        }
    }
}
