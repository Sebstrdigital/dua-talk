import Foundation

/// Full application configuration (matches Python config format)
struct AppConfig: Codable {
    var version: Int
    var hotkeys: HotkeyConfigs
    var activeMode: HotkeyMode
    var outputMode: OutputMode
    var history: [HistoryItem]
    var whisperModel: String
    var llmModel: String
    var language: Language
    var customPrompt: String
    var muteSounds: Bool

    struct HotkeyConfigs: Codable {
        var toggle: HotkeyConfig
        var pushToTalk: HotkeyConfig
        var textToSpeech: HotkeyConfig

        enum CodingKeys: String, CodingKey {
            case toggle
            case pushToTalk = "push_to_talk"
            case textToSpeech = "text_to_speech"
        }

        init(toggle: HotkeyConfig, pushToTalk: HotkeyConfig, textToSpeech: HotkeyConfig = .defaultTextToSpeech) {
            self.toggle = toggle
            self.pushToTalk = pushToTalk
            self.textToSpeech = textToSpeech
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            toggle = try container.decode(HotkeyConfig.self, forKey: .toggle)
            pushToTalk = try container.decode(HotkeyConfig.self, forKey: .pushToTalk)
            textToSpeech = try container.decodeIfPresent(HotkeyConfig.self, forKey: .textToSpeech) ?? .defaultTextToSpeech
        }
    }

    enum CodingKeys: String, CodingKey {
        case version
        case hotkeys
        case activeMode = "active_mode"
        case outputMode = "output_mode"
        case history
        case whisperModel = "whisper_model"
        case llmModel = "llm_model"
        case language
        case customPrompt = "custom_prompt"
        case muteSounds = "mute_sounds"
    }

    static let defaultCustomPrompt = "Clean up this dictation. Fix grammar, punctuation, and remove filler words. Output only the cleaned text."

    /// Default configuration
    static let `default` = AppConfig(
        version: 2,
        hotkeys: HotkeyConfigs(
            toggle: .defaultToggle,
            pushToTalk: .defaultPushToTalk,
            textToSpeech: .defaultTextToSpeech
        ),
        activeMode: .toggle,
        outputMode: .general,
        history: [],
        whisperModel: "small",
        llmModel: "gemma3",
        language: .english,
        customPrompt: defaultCustomPrompt,
        muteSounds: false
    )

    /// Maximum history items to keep
    static let historyLimit = 5

    /// Memberwise initializer
    init(version: Int, hotkeys: HotkeyConfigs, activeMode: HotkeyMode, outputMode: OutputMode, history: [HistoryItem], whisperModel: String, llmModel: String, language: Language, customPrompt: String = defaultCustomPrompt, muteSounds: Bool = false) {
        self.version = version
        self.hotkeys = hotkeys
        self.activeMode = activeMode
        self.outputMode = outputMode
        self.history = history
        self.whisperModel = whisperModel
        self.llmModel = llmModel
        self.language = language
        self.customPrompt = customPrompt
        self.muteSounds = muteSounds
    }

    /// Handle missing fields from old configs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        hotkeys = try container.decode(HotkeyConfigs.self, forKey: .hotkeys)
        activeMode = try container.decode(HotkeyMode.self, forKey: .activeMode)
        outputMode = try container.decode(OutputMode.self, forKey: .outputMode)
        history = try container.decode([HistoryItem].self, forKey: .history)
        let rawWhisperModel = try container.decode(String.self, forKey: .whisperModel)
        // Migrate removed base model to small
        if rawWhisperModel == "base" || rawWhisperModel == "base.en" {
            whisperModel = "small"
        } else {
            whisperModel = rawWhisperModel
        }
        llmModel = try container.decode(String.self, forKey: .llmModel)
        language = try container.decodeIfPresent(Language.self, forKey: .language) ?? .english
        customPrompt = try container.decodeIfPresent(String.self, forKey: .customPrompt) ?? Self.defaultCustomPrompt
        muteSounds = try container.decodeIfPresent(Bool.self, forKey: .muteSounds) ?? false
    }
}
