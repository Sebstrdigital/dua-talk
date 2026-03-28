import Foundation

private let abbreviations: Set<String> = [
    "Mr.", "Mrs.", "Ms.", "Dr.", "Prof.", "Jr.", "Sr.", "St.",
    "e.g.", "i.e.", "etc.", "vs.", "approx.", "dept.", "govt.", "corp."
]

private func isFragment(_ sentence: String) -> Bool {
    // Single-letter initial: "J." "K."
    if sentence.count <= 2 && sentence.hasSuffix(".") { return true }
    // Known abbreviation on its own: "Dr." "Prof."
    if abbreviations.contains(sentence) { return true }
    return false
}

func splitSentences(_ text: String) -> [String] {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return [] }

    var sentences: [String] = []
    trimmed.enumerateSubstrings(
        in: trimmed.startIndex..<trimmed.endIndex,
        options: .bySentences
    ) { substring, _, _, _ in
        if let sentence = substring {
            let cleaned = sentence.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty {
                sentences.append(cleaned)
            }
        }
    }

    // Merge single-letter "sentences" (initials like J. K.) back into the next sentence
    var merged: [String] = []
    var carry = ""
    for sentence in sentences {
        if !carry.isEmpty {
            carry += " " + sentence
            // Keep carrying if this is also a single-letter initial
            if isFragment(sentence) {
                continue
            }
            merged.append(carry)
            carry = ""
        } else if isFragment(sentence) {
            carry = sentence
        } else {
            merged.append(sentence)
        }
    }
    if !carry.isEmpty {
        if merged.isEmpty {
            merged.append(carry)
        } else {
            merged[merged.count - 1] += " " + carry
        }
    }

    return merged
}

func trimItem(_ text: String) -> String {
    var result = text.trimmingCharacters(in: .whitespaces)
    if result.isEmpty { return "" }
    
    // Remove leading conjunctions
    for prefix in ["and ", "or ", "but "] {
        if result.lowercased().hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
            break
        }
    }

    // Remove trailing period (keep ? and !)
    if result.hasSuffix(".") {
        result = String(result.dropLast())
    }

    // Capitalize first letter
    result = result.prefix(1).uppercased() + result.dropFirst()

    return result.trimmingCharacters(in: .whitespaces)
}

func findPreamble(_ sentences: [String], beforeIndex: Int) -> String? {
    if beforeIndex <= 0 { return nil }
    let preamble = sentences[0..<beforeIndex].joined(separator: " ")
    return preamble 
}









