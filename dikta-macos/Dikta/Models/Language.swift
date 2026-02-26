import Foundation

/// Supported languages for dictation
enum Language: String, Codable, CaseIterable {
    case english = "en"
    case swedish = "sv"
    case indonesian = "id"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .swedish: return "Svenska"
        case .indonesian: return "Bahasa Indonesia"
        }
    }

    /// Short code for menu bar display
    var menuBarCode: String {
        rawValue.uppercased()
    }

    /// Whisper language code
    var whisperCode: String {
        rawValue
    }

    /// Next language in the cycle
    var next: Language {
        let all = Language.allCases
        let index = all.firstIndex(of: self)!
        return all[(index + 1) % all.count]
    }
}
