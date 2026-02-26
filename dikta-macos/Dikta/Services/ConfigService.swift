import Foundation

/// Service for managing persistent configuration
@MainActor
final class ConfigService: ObservableObject {
    static let shared = ConfigService()

    private let configDir: URL
    private let configFile: URL

    @Published private(set) var config: AppConfig

    private init() {
        // ~/Library/Application Support/Dikta/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDir = appSupport.appendingPathComponent("Dikta")
        configFile = configDir.appendingPathComponent("config.json")

        // Load or create default config
        config = Self.load(from: configFile) ?? .default
    }

    private static func load(from url: URL) -> AppConfig? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            AppLogger.config.error("Failed to load config: \(error.localizedDescription)")
            return nil
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            // Atomic write: write to temp file, then rename to avoid corruption on crash
            let tempFile = configFile.appendingPathExtension("tmp")
            try data.write(to: tempFile)
            _ = try FileManager.default.replaceItemAt(configFile, withItemAt: tempFile)
        } catch {
            AppLogger.config.error("Failed to save config: \(error.localizedDescription)")
        }
    }

    // MARK: - Hotkey Management

    func getHotkey(for mode: HotkeyMode) -> HotkeyConfig {
        switch mode {
        case .toggle: return config.hotkeys.toggle
        case .pushToTalk: return config.hotkeys.pushToTalk
        case .textToSpeech: return config.hotkeys.textToSpeech
        case .languageToggle: return config.hotkeys.languageToggle
        }
    }

    func setHotkey(_ hotkey: HotkeyConfig, for mode: HotkeyMode) {
        switch mode {
        case .toggle:
            config.hotkeys.toggle = hotkey
        case .pushToTalk:
            config.hotkeys.pushToTalk = hotkey
        case .textToSpeech:
            config.hotkeys.textToSpeech = hotkey
        case .languageToggle:
            config.hotkeys.languageToggle = hotkey
        }
        objectWillChange.send()
        save()
    }

    var ttsHotkey: HotkeyConfig {
        config.hotkeys.textToSpeech
    }

    var languageToggleHotkey: HotkeyConfig {
        config.hotkeys.languageToggle
    }

    // MARK: - Output Mode

    var outputMode: OutputMode {
        get { config.outputMode }
        set {
            config.outputMode = newValue
            objectWillChange.send()
            save()
        }
    }

    // MARK: - History Management

    var history: [HistoryItem] {
        config.history
    }

    func addHistoryItem(text: String, mode: OutputMode? = nil) {
        let item = HistoryItem(text: text, outputMode: mode ?? outputMode)
        config.history.insert(item, at: 0)
        if config.history.count > AppConfig.historyLimit {
            config.history = Array(config.history.prefix(AppConfig.historyLimit))
        }
        save()
    }

    // MARK: - Model Configuration

    var whisperModel: String {
        get { config.whisperModel }
        set {
            config.whisperModel = newValue
            save()
        }
    }

    // MARK: - Custom Prompt

    var customPrompt: String {
        get { config.customPrompt }
        set {
            config.customPrompt = newValue
            objectWillChange.send()
            save()
        }
    }

    // MARK: - Mic Distance

    var micDistance: MicDistance {
        get { config.micDistance }
        set {
            config.micDistance = newValue
            objectWillChange.send()
            save()
        }
    }

    // MARK: - Mute Sounds

    var muteSounds: Bool {
        get { config.muteSounds }
        set {
            config.muteSounds = newValue
            objectWillChange.send()
            save()
        }
    }

    // MARK: - Mute Notifications

    var muteNotifications: Bool {
        get { config.muteNotifications }
        set {
            config.muteNotifications = newValue
            objectWillChange.send()
            save()
        }
    }

    // MARK: - Language

    var language: Language {
        get { config.language }
        set {
            config.language = newValue
            objectWillChange.send()
            save()
        }
    }
}
