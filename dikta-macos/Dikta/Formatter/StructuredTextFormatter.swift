import Foundation

struct StructuredTextFormatter: TextFormatter {

    enum ContentType {
        case bulletList(items: [String], preamble: String?)
        case numberedList(items: [String], preamble: String?)
        case paragraphs(groups: [[String]])
        case noChange
    }

    /// Optional embedding-based paragraph splitter.
    /// When nil (the default), the formatter runs in heuristic-only mode.
    /// Inject a non-nil value to enable semantic topic-shift detection.
    var embeddingSplitter: EmbeddingParagraphSplitter? = nil

    func format(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return ""  }

        // Already formatted?
        if trimmed.contains("\n- ") || trimmed.hasPrefix("- ")
            || trimmed.contains("\n1.") || trimmed.hasPrefix("1. ") { return trimmed }
        
        let sentences = splitSentences(trimmed)

        let contentType = analyze(sentences, fullText: trimmed)

        switch contentType {
        case .bulletList(let items, let preamble):
            return formatBullets(items, preamble: preamble)
        case .numberedList(let items, let preamble):
            return formatNumbered(items, preamble: preamble)
        case .paragraphs(let groups):
            return formatParagraphs(groups)
        case .noChange:
            return trimmed
        }
    }

    private func analyze(_ sentences: [String], fullText: String) -> ContentType {
        
        // Check A - Explicit enumeration

        let orderedMarkers = [
            "first", "firstly", "first of all",
            "second", "secondly", "third", "thirdly",
            "then", "next", "after that",
            "finally", "lastly", "last",
            "step one", "step two", "step three",
            "number one", "number two",
            "start by"
        ]

        let unorderedMarkers = [
            "also", "another", "another thing",
            "in addition", "plus", "on top of that" 
        ]

        var orderedCount = 0

        var unorderedCount = 0
        var markerIndices: [Int] = []

        for (i, sentence) in sentences.enumerated() {
            
            let lower = sentence.lowercased()

            if orderedMarkers.contains(where: { lower.hasPrefix($0) }) {
                
                orderedCount += 1
                markerIndices.append(i)
            } else if unorderedMarkers.contains(where: { lower.hasPrefix($0) }) {
                
                unorderedCount += 1
                markerIndices.append(i)
            }
        }

        let totalMarkers = orderedCount + unorderedCount
        if totalMarkers >= 3 {
            let startIndex = markerIndices.first ?? 0

            let items = markerIndices.map { sentences[$0] }
            let preamble = findPreamble(sentences, beforeIndex: startIndex)

            if orderedCount > unorderedCount {
                
                return .numberedList(items: items, preamble: preamble)
            } else {
                
                return .bulletList(items: items, preamble: preamble)
            }
        }

        // Check for "and then" chains in a single sentence

        if sentences.count <= 2 {
            let joined = sentences.joined(separator: " ")

            let parts = joined.components(separatedBy: " and then ")
            if parts.count >= 3 {
            
                return .numberedList(items: parts, preamble: nil)
            }

            let commaParts = joined.components(separatedBy: ", then ")
            if commaParts.count >= 3 {
                
                return .numberedList(items: commaParts, preamble: nil)
            }
        }

        // Check B - Colon-list

        if let colonIndex = fullText.firstIndex(of: ":") {
            let afterColon = String(fullText[fullText.index(after: colonIndex)...])

                .trimmingCharacters(in: .whitespaces)

            let beforeColon = String(fullText[..<colonIndex])

            // Check if what follows is a comma-seperated list ending the sentence
            let items = afterColon

                .trimmingCharacters(in: CharacterSet(charactersIn: "."))

                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

                .map { item -> String in
                    
                    var cleaned = item
                    for prefix in ["and ", "or "] {
                        
                        if cleaned.lowercased().hasPrefix(prefix) {
                            cleaned = String(cleaned.dropFirst(prefix.count))

                        }
                    }

                    return cleaned
                }
                .filter { !$0.isEmpty }
            if items.count >= 3 {

                return .bulletList(items: items, preamble: beforeColon + ":")
            }

        }

        // Check C - Homogeneous short sentences
        // Skip if any sentence starts with a topic-shift transition phrase — those should
        // be handled by the paragraph-splitting pass below instead.
        let topicShiftPrefixes = [
            "how about", "by the way", "on another note", "on a different note",
            "on the other hand", "one more thing", "besides that", "apart from that",
            "moving on", "additionally", "furthermore", "moreover", "separately",
            "regarding", "as for", "however", "that said", "anyway", "also",
            "okay", "ok", "yeah", "alright"
        ]
        let hasTopicShift = sentences.contains { s in
            let lower = s.lowercased()
            return topicShiftPrefixes.contains(where: { lower.hasPrefix($0) })
        }

        let allShort = sentences.allSatisfy { $0.components(separatedBy: " ").count < 15 }
        if allShort && sentences.count >= 3 && !hasTopicShift {

            let nonVerbStarts: Set<String> = [
                "i", "we", "he", "she", "it", "they", "you",
                "my", "our", "his", "her", "its", "their",
                "the", "a", "an", "in", "on", "at", "for", "with", "to",
                "from", "by", "of", "about", "and", "but", "or", "so", "yet",
                "this", "that", "these", "those", "one", "two", "first",
                "second", "each", "all", "most", "some", "many", "every",
                "several", "both", "neither", "either"
            ]

            let imperativeCount = sentences.filter { sentence in

                let firstWord = sentence.components(separatedBy: " ").first?
                    .lowercased()

                    .trimmingCharacters(in: CharacterSet(charactersIn: ".!?,")) ?? ""
                return !nonVerbStarts.contains(firstWord)

            }.count

            let ratio = Double(imperativeCount) / Double(sentences.count)

            if ratio >= 0.6 {
                return .numberedList(items: sentences, preamble: nil)
            } else if sentences.count < 5 {
                return .bulletList(items: sentences, preamble: nil)
            }
            // For 5+ sentences with low imperative ratio, fall through to
            // paragraph splitting / long-text fallback below.

        }

        // Check D - Sections / Paragraph Splitting
        let transitionPhrases = [
            "how about",
            "by the way", "another thing", "on another note",
            "on a different note", "on the other hand",
            "in addition", "one more thing", "besides that",
            "apart from that", "moving on",
            "additionally", "furthermore", "moreover",
            "separately", "regarding", "as for",
            "also", "however", "that said", "anyway",
            "okay", "ok", "yeah", "alright"
        ]

        var groups: [[String]] = [[]]

        for sentence in sentences {
            let lower = sentence.lowercased()

            let isTransition = transitionPhrases.contains { lower.hasPrefix($0) }

            if isTransition && !groups.last!.isEmpty {
                groups.append([sentence])

            } else {
                groups[groups.count - 1].append(sentence)
            }
        }

        // Check D (embedding augmentation) — consult the embedding splitter for
        // additional break points that heuristics may have missed.
        if let splitter = embeddingSplitter, sentences.count >= 2 {
            let embeddingBreaks = splitter.breakIndices(for: sentences)
            if !embeddingBreaks.isEmpty {
                if groups.count == 1 {
                    // No heuristic splits — build groups entirely from embedding breaks.
                    groups = groupsFromBreakIndices(embeddingBreaks, sentences: sentences)
                } else {
                    // Heuristics already split — merge in embedding breaks without
                    // removing any existing boundaries.
                    groups = mergeEmbeddingBreaks(
                        embeddingBreaks,
                        into: groups,
                        sentences: sentences
                    )
                }
            }
        }

        if groups.count >= 2 && groups.count <= 8 && !groups[0].isEmpty {
            return .paragraphs(groups: groups)
        }

        // Check E - Long-text fallback: split at midpoint when many sentences
        if sentences.count >= 5 {
            let mid = sentences.count / 2
            let firstHalf = Array(sentences[0..<mid])
            let secondHalf = Array(sentences[mid...])
            return .paragraphs(groups: [firstHalf, secondHalf])
        }

        // Check F - No pattern
        return .noChange
    }

    private let sequenceMarkers = [
        "first, ", "firstly, ", "first of all, ",
        "second, ", "secondly, ", "third, ", "thirdly, ",
        "also, ", "also ", "another thing, ", "another thing is ",
        "in addition, ", "plus, ", "plus ", "next, ", "next ",
        "finally, ", "lastly, ", "last, ", "on top of that, ",
        "then, ", "then ", "after that, ", "after that ",
        "start by ", "step one, ", "step two, ", "step three, ",
        "number one, ", "number two, "
    ]

    private func stripMarker(_ text: String) -> String {
        let lower = text.lowercased()
        for marker in sequenceMarkers {
            if lower.hasPrefix(marker) {
                return String(text.dropFirst(marker.count))
            }
        }
        return text
    }

    private func stripFiller(_ text: String) -> String {
        let lower = text.lowercased()
        let fillers = [
            "you need to ", "you should ", "you have to ",
            "you can ", "you "
        ]
        for filler in fillers {
            if lower.hasPrefix(filler) {
                return String(text.dropFirst(filler.count))
            }
        }
        return text
    }

    private func formatBullets(_ items: [String], preamble: String?) -> String {
        var result = ""
        if let p = preamble {
            result += p + "\n\n"
        }
        let bullets = items.map { "- " + trimItem(stripMarker($0)) }
        result += bullets.joined(separator: "\n")
        return result
    }

    private func formatNumbered(_ items: [String], preamble: String?) -> String {
        var result = ""
        if let p = preamble {
            result += p + "\n\n"
        }
        let steps = items.enumerated().map { (i, item) in
            "\(i + 1). " + trimItem(stripFiller(stripMarker(item)))
        }
        result += steps.joined(separator: "\n")
        return result
    }

    private func formatParagraphs(_ groups: [[String]]) -> String {
        return groups
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: " ") }
            .joined(separator: "\n\n")
    }

    // MARK: - Embedding integration helpers

    /// Converts a sorted list of break indices into `[[String]]` groups.
    /// A break index `i` means a new group starts at `sentences[i + 1]`.
    private func groupsFromBreakIndices(_ breakIndices: [Int], sentences: [String]) -> [[String]] {
        var result: [[String]] = [[]]
        for (i, sentence) in sentences.enumerated() {
            result[result.count - 1].append(sentence)
            if breakIndices.contains(i) && i < sentences.count - 1 {
                result.append([])
            }
        }
        return result.filter { !$0.isEmpty }
    }

    /// Merges embedding break indices into an existing set of heuristic groups.
    /// Only adds new group boundaries — never removes or reorders existing ones.
    private func mergeEmbeddingBreaks(
        _ embeddingBreaks: [Int],
        into heuristicGroups: [[String]],
        sentences: [String]
    ) -> [[String]] {
        // Compute the sentence indices that already act as heuristic boundaries
        // (i.e. the last sentence index of each group except the last).
        var heuristicBreaks = Set<Int>()
        var idx = 0
        for (g, group) in heuristicGroups.enumerated() {
            idx += group.count
            if g < heuristicGroups.count - 1 {
                heuristicBreaks.insert(idx - 1)
            }
        }

        // Union of both break sets, then rebuild groups from scratch.
        let allBreaks = heuristicBreaks.union(embeddingBreaks).sorted()
        return groupsFromBreakIndices(allBreaks, sentences: sentences)
    }

}
