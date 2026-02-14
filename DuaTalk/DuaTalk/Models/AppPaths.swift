import Foundation

/// Centralized app file paths — everything under ~/Library/Application Support/Dua Talk/
enum AppPaths {
    /// ~/Library/Application Support/Dua Talk/
    static let appSupport: String = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Dua Talk").path
    }()

    // MARK: - LLM

    /// ~/Library/Application Support/Dua Talk/models/
    static let modelsDir = appSupport + "/models"

    /// Full path to the GGUF model file
    static let llmModelPath = modelsDir + "/gemma-3-4b-it-Q4_K_M.gguf"

    // MARK: - TTS (Kokoro)

    /// ~/Library/Application Support/Dua Talk/kokoro_server.py
    static let kokoroServerScript = appSupport + "/kokoro_server.py"

    /// ~/Library/Application Support/Dua Talk/venv/bin/python
    static let venvPython = appSupport + "/venv/bin/python"

    /// ~/Library/Application Support/Dua Talk/venv/
    static let venvDir = appSupport + "/venv"
}
