import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Migrate from old "Dua Talk" directory if needed
        AppPaths.migrateIfNeeded()
        // Copy bundled kokoro_server.py to Application Support if missing
        copyBundledServerScript()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        OnboardingWindowController.shared.show()
        return true
    }

    private func copyBundledServerScript() {
        let fm = FileManager.default
        let dest = AppPaths.kokoroServerScript

        guard !fm.fileExists(atPath: dest),
              let bundled = Bundle.main.path(forResource: "kokoro_server", ofType: "py") else {
            return
        }

        do {
            let dir = AppPaths.appSupport
            if !fm.fileExists(atPath: dir) {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            }
            try fm.copyItem(atPath: bundled, toPath: dest)
        } catch {
            AppLogger.general.error("Failed to copy kokoro_server.py: \(error.localizedDescription)")
        }
    }
}

@main
struct DiktaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.menu)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        let icon: some View = {
            switch viewModel.appState {
            case .idle:
                return Image(systemName: "mic")
            case .loading:
                return Image(systemName: "hourglass")
            case .recording:
                return Image(systemName: "record.circle.fill")
            case .processing:
                return Image(systemName: "hourglass")
            case .speaking:
                return Image(systemName: "speaker.wave.2.fill")
            }
        }()

        HStack(spacing: 2) {
            icon
            Text(viewModel.configService.language.menuBarCode)
                .font(.caption2)
        }
    }
}
