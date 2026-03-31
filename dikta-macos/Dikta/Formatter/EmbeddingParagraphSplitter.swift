import Foundation

// MARK: - Embedding provider protocol

/// Abstraction over SentenceEmbeddingService so tests can inject pre-computed vectors.
protocol EmbeddingProvider {
    /// Returns one L2-normalised float vector per input sentence.
    func embeddings(for sentences: [String]) throws -> [[Float]]
}

// MARK: - Production adapter

/// Bridges the singleton SentenceEmbeddingService to the EmbeddingProvider protocol.
struct LiveEmbeddingProvider: EmbeddingProvider {
    func embeddings(for sentences: [String]) throws -> [[Float]] {
        return try SentenceEmbeddingService.shared.embeddings(for: sentences)
    }
}

// MARK: - Splitter

/// Uses sentence embeddings and TextTiling depth-score analysis to detect topic-shift
/// paragraph boundaries in a sequence of sentences.
///
/// The splitter is stateless and side-effect-free. It falls back gracefully to an
/// empty break list whenever the embedding provider is unavailable.
///
/// Algorithm (TextTiling depth score):
///   For each gap i between sentence[i] and sentence[i+1]:
///     left_peak  = max(sim[i-1], sim[i])   (or sim[i] when i == 0)
///     right_peak = max(sim[i], sim[i+1])   (or sim[i] when i == last)
///     depth[i]   = (left_peak − sim[i]) + (right_peak − sim[i])
///   Gaps with depth > threshold are returned as break indices.
struct EmbeddingParagraphSplitter {

    // MARK: - Configuration

    /// Minimum depth score to declare a paragraph break.
    /// Calibrated against prototype testing with MiniLM-L12-v2:
    /// true topic shifts produced depths ≥ 0.474; noise was below 0.20.
    var depthThreshold: Float = 0.20

    /// Maximum words-per-sentence for the "all short questions" guard.
    /// If every sentence is at or below this length, skip embedding analysis
    /// to prevent false breaks in rapid-fire personal question sequences.
    var shortQuestionWordLimit: Int = 7

    /// Embedding provider (injectable for tests; defaults to live CoreML model).
    var embeddingProvider: EmbeddingProvider

    // MARK: - Init

    init(
        depthThreshold: Float = 0.20,
        shortQuestionWordLimit: Int = 7,
        embeddingProvider: EmbeddingProvider = LiveEmbeddingProvider()
    ) {
        self.depthThreshold = depthThreshold
        self.shortQuestionWordLimit = shortQuestionWordLimit
        self.embeddingProvider = embeddingProvider
    }

    // MARK: - Public API

    /// Returns the sentence indices after which a paragraph break should be inserted.
    ///
    /// For example, returning `[2]` means a break between sentence[2] and sentence[3].
    ///
    /// - Parameter sentences: Pre-split sentences from `splitSentences(_:)`.
    /// - Returns: Sorted list of gap indices where breaks should be placed.
    func breakIndices(for sentences: [String]) -> [Int] {
        guard sentences.count >= 2 else { return [] }

        // Guard: suppress embedding analysis for pure short-question sequences.
        // MiniLM produces false breaks in quick back-and-forth personal questions
        // where all sentences are very short.
        if allShortQuestions(sentences) { return [] }

        // Compute embeddings — fall back to empty on any error.
        let embeddings: [[Float]]
        do {
            embeddings = try embeddingProvider.embeddings(for: sentences)
        } catch {
            return []
        }

        guard embeddings.count == sentences.count else { return [] }

        // Cosine similarities for each adjacent pair.
        let similarities: [Float] = (0..<sentences.count - 1).map { i in
            SentenceEmbeddingService.cosineSimilarity(embeddings[i], embeddings[i + 1])
        }

        // Depth scores via TextTiling.
        var breaks: [Int] = []
        for i in 0..<similarities.count {
            let leftPeak: Float  = i > 0 ? max(similarities[i - 1], similarities[i]) : similarities[i]
            let rightPeak: Float = i < similarities.count - 1 ? max(similarities[i], similarities[i + 1]) : similarities[i]
            let depth = (leftPeak - similarities[i]) + (rightPeak - similarities[i])
            if depth > depthThreshold {
                breaks.append(i)
            }
        }
        return breaks
    }

    // MARK: - Private helpers

    private func allShortQuestions(_ sentences: [String]) -> Bool {
        return sentences.allSatisfy { sentence in
            let wordCount = sentence
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }.count
            return wordCount <= shortQuestionWordLimit
        }
    }
}
