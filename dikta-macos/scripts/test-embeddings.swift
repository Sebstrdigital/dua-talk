#!/usr/bin/env swift

import Foundation
import NaturalLanguage

// MARK: - Sentence splitter (same logic as production)

let abbreviations: Set<String> = [
    "Mr.", "Mrs.", "Ms.", "Dr.", "Prof.", "Jr.", "Sr.", "St.",
    "e.g.", "i.e.", "etc.", "vs.", "approx.", "dept.", "govt.", "corp."
]

func splitSentences(_ text: String) -> [String] {
    var sentences: [String] = []
    var current = ""
    let chars = Array(text)
    var i = 0
    while i < chars.count {
        current.append(chars[i])
        if chars[i] == "." || chars[i] == "!" || chars[i] == "?" {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            let isAbbreviation = abbreviations.contains(where: { trimmed.hasSuffix($0) })
            if !isAbbreviation {
                sentences.append(trimmed)
                current = ""
            }
        }
        i += 1
    }
    let leftover = current.trimmingCharacters(in: .whitespaces)
    if !leftover.isEmpty { sentences.append(leftover) }
    return sentences
}

// MARK: - Cosine similarity via NLEmbedding

func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
    let dot = zip(a, b).reduce(0.0) { $0 + $1.0 * $1.1 }
    let magA = sqrt(a.reduce(0.0) { $0 + $1 * $1 })
    let magB = sqrt(b.reduce(0.0) { $0 + $1 * $1 })
    guard magA > 0 && magB > 0 else { return 0 }
    return dot / (magA * magB)
}

// MARK: - Test messages

let testMessages: [(name: String, text: String)] = [
    ("Test 1 — Reino work+personal",
     "Hello, Reino! So, we have some work to do I guess. There is three things that I want to go through. First things first, there is a new document that we need to take a look at. Second thing, I have some feedback regarding a code review. And the third thing, we need to set a date for when we're going to start working. Okay, so how is life? How are you? How is my mom? Any news about the new car? Okay, have a good day. Best regards, Sebastian."),

    ("Test 2 — Reino meeting+personal",
     "Hi Reino! So we need to have a new meeting where we can discuss the project and how to move forward. Can you have time tomorrow for a meeting at 4 o'clock? PM? How's the family? Is everything okay? Are you preparing for the Easter festivities? How's your health? Everything good? Okay that's all. Best regards, Sebastian."),

    ("Test 3 — Pure work (no topic shift expected)",
     "We need to update the database schema before Friday. The migration script is ready but needs testing. I also updated the API endpoints to match the new schema. Please review the pull request when you get a chance."),

    ("Test 4 — Pure personal (no topic shift expected)",
     "How are you doing? How's the family? Are the kids enjoying school? Did you end up getting that new car you were looking at?")
]

// MARK: - Run analysis

guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
    print("ERROR: NLEmbedding.sentenceEmbedding not available for English")
    exit(1)
}

print("NLEmbedding loaded: \(embedding.dimension)-dimensional vectors")
print("=" * 80)

for test in testMessages {
    print("\n\(test.name)")
    print("-" * 60)

    let sentences = splitSentences(test.text)

    // Get embeddings
    var vectors: [[Double]] = []
    for s in sentences {
        if let vec = embedding.vector(for: s) {
            vectors.append(vec)
        } else {
            vectors.append([])
            print("  WARNING: No embedding for: \(s.prefix(50))...")
        }
    }

    // Compute adjacent similarity
    var similarities: [Double] = []
    for i in 0..<(sentences.count - 1) {
        if vectors[i].isEmpty || vectors[i + 1].isEmpty {
            similarities.append(0)
        } else {
            let sim = cosineSimilarity(vectors[i], vectors[i + 1])
            similarities.append(sim)
        }
    }

    // Also compute NLEmbedding's built-in distance for comparison
    var distances: [Double] = []
    for i in 0..<(sentences.count - 1) {
        let dist = embedding.distance(between: sentences[i], and: sentences[i + 1], distanceType: .cosine)
        distances.append(dist)
    }

    // Compute depth scores (how much similarity drops at each gap)
    var depthScores: [Double] = []
    for i in 0..<similarities.count {
        let left = (i > 0) ? max(similarities[i - 1], similarities[i]) : similarities[i]
        let right = (i < similarities.count - 1) ? max(similarities[i], similarities[i + 1]) : similarities[i]
        let depth = (left - similarities[i]) + (right - similarities[i])
        depthScores.append(depth)
    }

    // Print results
    print("  Sentences:")
    for (i, s) in sentences.enumerated() {
        let preview = s.count > 70 ? String(s.prefix(67)) + "..." : s
        print("  [\(i)] \(preview)")
    }

    print("\n  Adjacent similarities (cosine):")
    for i in 0..<similarities.count {
        let sim = similarities[i]
        let depth = depthScores[i]
        let bar = String(repeating: "█", count: Int(sim * 30))
        let marker = depth > 0.15 ? " ◄◄ BREAK (depth=\(String(format: "%.3f", depth)))" : ""
        print("  [\(i)]→[\(i+1)]  sim=\(String(format: "%.3f", sim))  depth=\(String(format: "%.3f", depth))  \(bar)\(marker)")
    }

    // Show suggested breaks
    let breaks = depthScores.enumerated()
        .filter { $0.element > 0.15 }
        .sorted { $0.element > $1.element }
    if breaks.isEmpty {
        print("\n  → No paragraph breaks suggested (no depth > 0.15)")
    } else {
        print("\n  → Suggested breaks after sentences: \(breaks.map { "[\($0.offset)] (depth \(String(format: "%.3f", $0.element)))" }.joined(separator: ", "))")
    }
}

print("\n" + "=" * 80)
print("Done.")

// Helper
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
