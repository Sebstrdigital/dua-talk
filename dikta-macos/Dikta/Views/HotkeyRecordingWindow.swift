import SwiftUI
import AppKit

/// Window controller for hotkey recording
@MainActor
final class HotkeyRecordingWindowController {
    private var window: NSWindow?
    private var hostingView: NSHostingView<HotkeyRecordingView>?
    private var windowDelegate: WindowDelegate?
    private weak var viewModel: MenuBarViewModel?

    func show(for mode: HotkeyMode, viewModel: MenuBarViewModel) {
        // Close existing window if any
        close()

        self.viewModel = viewModel

        let contentView = HotkeyRecordingView(mode: mode, viewModel: viewModel) { [weak self] in
            self?.close()
        }

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 160)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set \(mode.displayName) Hotkey"
        window.contentView = hostingView
        window.center()
        window.level = .floating
        window.isReleasedWhenClosed = false

        // Handle window close - store delegate to keep it alive
        let delegate = WindowDelegate { [weak self] in
            Task { @MainActor in
                self?.viewModel?.cancelHotkeyRecording()
            }
        }
        self.windowDelegate = delegate
        window.delegate = delegate

        self.window = window
        self.hostingView = hostingView

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
        hostingView = nil
        windowDelegate = nil
    }
}

private class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

/// View for hotkey recording
struct HotkeyRecordingView: View {
    let mode: HotkeyMode
    @ObservedObject var viewModel: MenuBarViewModel
    let onDismiss: () -> Void

    @State private var hasRecordedHotkey = false

    /// Whether a collision alert is currently being shown
    private var showCollisionAlert: Binding<Bool> {
        Binding(
            get: { viewModel.pendingCollision != nil },
            set: { _ in }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(hasRecordedHotkey ? "Hotkey recorded" : "Press your desired key combination")
                .font(.headline)

            Text(mode.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            let hotkey = viewModel.configService.getHotkey(for: mode)

            if viewModel.isRecordingHotkey {
                Text("Waiting for keys...")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            } else if viewModel.pendingCollision != nil {
                Text("Conflict detected")
                    .foregroundColor(.orange)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
            } else {
                Text(hotkey.displayString.isEmpty ? "Not set" : hotkey.displayString)
                    .font(.title)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(hasRecordedHotkey ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.cancelHotkeyRecording()
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                if hasRecordedHotkey && viewModel.pendingCollision == nil {
                    Button("Try Again") {
                        hasRecordedHotkey = false
                        viewModel.startRecordingHotkeyDirect(for: mode)
                    }

                    Button("Save") {
                        onDismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .frame(width: 320, height: 160)
        .onAppear {
            viewModel.startRecordingHotkeyDirect(for: mode)
        }
        .onChange(of: viewModel.isRecordingHotkey) { _, isRecording in
            if !isRecording && !hasRecordedHotkey && viewModel.pendingCollision == nil {
                hasRecordedHotkey = true
            }
        }
        .alert(
            collisionAlertTitle,
            isPresented: showCollisionAlert,
            presenting: viewModel.pendingCollision
        ) { collision in
            Button("Override — Clear \(collision.conflictingMode.displayName)", role: .destructive) {
                viewModel.resolveCollisionOverride()
                hasRecordedHotkey = true
            }
            Button("Try Again", role: .cancel) {
                hasRecordedHotkey = false
                viewModel.resolveCollisionCancel()
            }
        } message: { collision in
            Text("\(collision.newHotkey.displayString) is already used by \(collision.conflictingMode.displayName). Override it or choose a different hotkey.")
        }
    }

    private var collisionAlertTitle: String {
        if let collision = viewModel.pendingCollision {
            return "Hotkey Conflict: \(collision.newHotkey.displayString)"
        }
        return "Hotkey Conflict"
    }
}
