import Foundation

/// Mic distance presets that control speech detection sensitivity
enum MicDistance: String, Codable, CaseIterable {
    case close
    case normal
    case far

    var displayName: String {
        switch self {
        case .close: return "Close"
        case .normal: return "Normal"
        case .far: return "Far / Headset"
        }
    }

    /// Whisper noSpeechThreshold — higher = more likely to reject quiet audio
    var noSpeechThreshold: Float {
        switch self {
        case .close: return 0.6
        case .normal: return 0.3
        case .far: return 0.15
        }
    }

    /// Whisper logProbThreshold — lower = accepts lower-confidence transcriptions
    var logProbThreshold: Float {
        switch self {
        case .close: return -1.0
        case .normal: return -1.5
        case .far: return -2.0
        }
    }
}
