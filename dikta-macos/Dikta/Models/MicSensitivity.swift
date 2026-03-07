import Foundation

/// Mic sensitivity presets that control Whisper's speech detection thresholds
/// and silence detection in AudioRecorder.
///
/// Two Whisper decoding thresholds are tuned per preset:
/// - `noSpeechThreshold`: Whisper's internal classifier score for "no speech". Higher values
///   cause Whisper to more aggressively classify audio as silence. Bluetooth headsets deliver
///   quieter signals, triggering false "No Speech" results at the default 0.6.
/// - `logProbThreshold`: Average log-probability of output tokens. Lower (more negative) values
///   allow Whisper to accept lower-confidence transcriptions, needed for quiet headset audio.
enum MicSensitivity: String, Codable, CaseIterable {
    case normal
    case headset

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .headset: return "Headset"
        }
    }

    /// Whisper `noSpeechThreshold` — higher = more likely to reject quiet audio as silence.
    /// Range is 0.0–1.0; Whisper's default is 0.6.
    var noSpeechThreshold: Float {
        switch self {
        case .normal: return 0.3  // Relaxed: avoids false negatives from desk-distance input
        case .headset: return 0.15 // Permissive: required for Bluetooth/headset weak signals
        }
    }

    /// RMS energy threshold for silence detection in `AudioRecorder`.
    /// Audio chunks with RMS below this level are considered silence.
    var silenceRMSThreshold: Float {
        switch self {
        case .normal: return 0.005  // Balanced: default, matches previous hardcoded value
        case .headset: return 0.001 // Lower: weak Bluetooth signals need a very permissive floor
        }
    }

    /// Whisper `logProbThreshold` — lower (more negative) = accepts lower-confidence output.
    /// Whisper's default is -1.0.
    var logProbThreshold: Float {
        switch self {
        case .normal: return -1.5 // Relaxed: allows moderate confidence drop at desk distance
        case .headset: return -2.0 // Permissive: needed for AirPods where signal attenuation is high
        }
    }
}
