import Foundation

/// Minimal file logger for diagnosing "No Speech" issues.
/// Writes to ~/Library/Logs/Dikta/dikta-diagnostic.log
final class DiagnosticLogger {
    static let shared = DiagnosticLogger()

    private var _isEnabled = false
    private let queue = DispatchQueue(label: "com.dikta.diagnostic-logger")

    /// Thread-safe enabled flag, set from ConfigService on launch and when toggled
    var isEnabled: Bool {
        get { queue.sync { _isEnabled } }
        set { queue.sync { _isEnabled = newValue } }
    }
    private let logURL: URL
    private let maxFileSize: UInt64 = 5 * 1024 * 1024 // 5 MB

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Dikta")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        logURL = logsDir.appendingPathComponent("dikta-diagnostic.log")
    }

    func log(_ message: String) {
        queue.async { [self] in
            guard self._isEnabled else { return }
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] \(message)\n"

            // Rotate if over 5 MB: keep last half
            if let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
               let size = attrs[.size] as? UInt64, size > maxFileSize {
                if let data = try? Data(contentsOf: logURL) {
                    let keepFrom = data.count / 2
                    try? data[keepFrom...].write(to: logURL)
                }
            }

            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logURL.path) {
                    if let handle = try? FileHandle(forWritingTo: logURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: logURL)
                }
            }
        }
    }
}
