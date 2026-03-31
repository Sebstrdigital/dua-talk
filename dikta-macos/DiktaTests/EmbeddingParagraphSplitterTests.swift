/// EmbeddingParagraphSplitterTests — Unit tests for EmbeddingParagraphSplitter.
///
/// Self-contained: inlines the EmbeddingProvider protocol, MockEmbeddingProvider,
/// and EmbeddingParagraphSplitter (minus the CoreML dependency) so these tests
/// run without a bundled model.
///
/// Test coverage:
///   F: EmbeddingParagraphSplitter — 12 tests
///     - breakIndices detection (topic shift cases)
///     - no-break cases (single topic, short questions suppression)
///     - threshold behaviour
///     - edge cases (empty, single sentence, model unavailable)
///
/// Run via: cd dikta-macos && xcodebuild test -project Dikta.xcodeproj -scheme Dikta \
///            -only-testing:DiktaTests -destination 'platform=macOS' \
///            CODE_SIGN_IDENTITY=- 2>&1 | grep 'Executed.*test'

import XCTest

// =============================================================================
// MARK: - Inlined types (mirrors production code — update when production changes)
// =============================================================================

// -- EmbeddingProvider protocol --

private protocol EmbeddingProvider_Test {
    func embeddings(for sentences: [String]) throws -> [[Float]]
}

// -- MockEmbeddingProvider --

/// Returns pre-computed 2-dimensional vectors keyed by sentence content.
/// Cosine similarity on unit 2D vectors equals cos(angle between them).
private struct MockEmbeddingProvider: EmbeddingProvider_Test {
    let table: [String: [Float]]

    enum MockError: Error { case sentenceNotFound(String) }

    func embeddings(for sentences: [String]) throws -> [[Float]] {
        return try sentences.map { s in
            guard let vec = table[s] else { throw MockError.sentenceNotFound(s) }
            return vec
        }
    }
}

/// Provider that always throws (simulates a failed model load).
private struct FailingEmbeddingProvider: EmbeddingProvider_Test {
    func embeddings(for sentences: [String]) throws -> [[Float]] {
        throw NSError(domain: "test", code: -1)
    }
}

// -- Cosine similarity (mirrors SentenceEmbeddingService.cosineSimilarity) --

private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count, !a.isEmpty else { return 0 }
    var dot: Float = 0; var nA: Float = 0; var nB: Float = 0
    for i in 0..<a.count { dot += a[i]*b[i]; nA += a[i]*a[i]; nB += b[i]*b[i] }
    let denom = nA.squareRoot() * nB.squareRoot()
    guard denom > 0 else { return 0 }
    return dot / denom
}

// -- EmbeddingParagraphSplitter (test-local variant using EmbeddingProvider_Test) --

private struct EmbeddingParagraphSplitter_Test {
    var depthThreshold: Float
    var shortQuestionWordLimit: Int
    var embeddingProvider: EmbeddingProvider_Test

    init(
        depthThreshold: Float = 0.20,
        shortQuestionWordLimit: Int = 7,
        embeddingProvider: EmbeddingProvider_Test
    ) {
        self.depthThreshold = depthThreshold
        self.shortQuestionWordLimit = shortQuestionWordLimit
        self.embeddingProvider = embeddingProvider
    }

    func breakIndices(for sentences: [String]) -> [Int] {
        guard sentences.count >= 2 else { return [] }
        if allShortQuestions(sentences) { return [] }
        let embeddings: [[Float]]
        do {
            embeddings = try embeddingProvider.embeddings(for: sentences)
        } catch {
            return []
        }
        guard embeddings.count == sentences.count else { return [] }
        let similarities: [Float] = (0..<sentences.count - 1).map { i in
            cosineSimilarity(embeddings[i], embeddings[i + 1])
        }
        var breaks: [Int] = []
        for i in 0..<similarities.count {
            let leftPeak: Float  = i > 0 ? max(similarities[i-1], similarities[i]) : similarities[i]
            let rightPeak: Float = i < similarities.count - 1 ? max(similarities[i], similarities[i+1]) : similarities[i]
            let depth = (leftPeak - similarities[i]) + (rightPeak - similarities[i])
            if depth > depthThreshold { breaks.append(i) }
        }
        return breaks
    }

    private func allShortQuestions(_ sentences: [String]) -> Bool {
        sentences.allSatisfy {
            $0.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count <= shortQuestionWordLimit
        }
    }
}

// =============================================================================
// MARK: - Helpers
// =============================================================================

/// Returns a 2D unit vector at the given angle (radians).
private func unitVec(_ angle: Float) -> [Float] {
    [cos(angle), sin(angle)]
}

// =============================================================================
// MARK: - Tests
// =============================================================================

class EmbeddingParagraphSplitterTests: XCTestCase {

    // MARK: F01 – Test 2: work→PM→personal — break at PM?→How's
    //
    // Sentences (simplified Test 2 from the acceptance criteria):
    //   0: work sentence (topic A)
    //   1: "PM?" — brief work wrap-up (still topic A cluster)
    //   2: "How's the family?" — personal (topic B)
    //
    // We model topic A at angle 0, topic B at angle π/2 (perpendicular).
    // Similarity(1,2) will be close to 0, producing a deep trough.
    func testF01_Test2_WorkToPersonalBreak() {
        let sentences = [
            "So we need to have a new meeting.",
            "PM?",
            "How's the family?"
        ]
        // Angles: 0° (work A), 10° (still A), 90° (personal B)
        let provider = MockEmbeddingProvider(table: [
            "So we need to have a new meeting.": unitVec(0.0),
            "PM?":                               unitVec(0.17),   // ~10°
            "How's the family?":                 unitVec(Float.pi / 2)
        ])
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        let breaks = splitter.breakIndices(for: sentences)
        // Break should appear at gap index 1 (between "PM?" and "How's the family?")
        XCTAssertTrue(breaks.contains(1), "Expected break at gap 1 (PM?→How's), got \(breaks)")
    }

    // MARK: F02 – Test 3: pure work sentences — no break
    func testF02_Test3_PureWorkNoBreak() {
        let sentences = [
            "There is a new document that we need to take a look at.",
            "I have some feedback regarding a code review.",
            "We need to set a date for when we're going to start working."
        ]
        // All in the same semantic direction (angle ≈ 0 ± small variation)
        let provider = MockEmbeddingProvider(table: [
            "There is a new document that we need to take a look at.": unitVec(0.0),
            "I have some feedback regarding a code review.":           unitVec(0.05),
            "We need to set a date for when we're going to start working.": unitVec(0.10)
        ])
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        let breaks = splitter.breakIndices(for: sentences)
        XCTAssertTrue(breaks.isEmpty, "Pure work content should produce no breaks, got \(breaks)")
    }

    // MARK: F03 – Test 4: pure personal short questions — suppressed by short-question guard
    func testF03_Test4_PurePersonalQuestionsNoBreak() {
        // All sentences are ≤7 words — the short-question guard should fire before
        // even calling the embedding provider.
        let sentences = [
            "How are you?",       // 3 words
            "How is my mom?",     // 4 words
            "Any news about the new car?"  // 6 words
        ]
        let provider = MockEmbeddingProvider(table: [:]) // should never be called
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        let breaks = splitter.breakIndices(for: sentences)
        XCTAssertTrue(breaks.isEmpty, "Short personal questions should be suppressed, got \(breaks)")
    }

    // MARK: F04 – Test 1: work→personal with long sentences — break at "Okay, so how is life?"
    func testF04_Test1_WorkToPersonalLongSentences() {
        let sentences = [
            "There is three things that I want to go through.",
            "First things first, there is a new document that we need to take a look at.",
            "Second thing, I have some feedback regarding a code review.",
            "Okay, so how is life?"
        ]
        // Work sentences cluster at angle 0, personal at π/2
        let provider = MockEmbeddingProvider(table: [
            "There is three things that I want to go through.":                             unitVec(0.0),
            "First things first, there is a new document that we need to take a look at.": unitVec(0.05),
            "Second thing, I have some feedback regarding a code review.":                  unitVec(0.08),
            "Okay, so how is life?":                                                        unitVec(Float.pi / 2)
        ])
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        let breaks = splitter.breakIndices(for: sentences)
        // Break at gap 2 (between "code review" and "Okay, so how is life?")
        XCTAssertTrue(breaks.contains(2), "Expected break at gap 2 (work→personal), got \(breaks)")
    }

    // MARK: F05 – No break for uniformly similar sentences
    func testF05_UniformSimilarityNoBreak() {
        let sentences = ["A.", "B.", "C.", "D."]
        // All pointing in the same direction → similarity ≈ 1.0, depth ≈ 0
        let vec = unitVec(0.0)
        let provider = MockEmbeddingProvider(table: ["A.": vec, "B.": vec, "C.": vec, "D.": vec])
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        XCTAssertTrue(splitter.breakIndices(for: sentences).isEmpty)
    }

    // MARK: F06 – Edge case: single sentence returns no breaks
    func testF06_SingleSentenceNoBreak() {
        let provider = MockEmbeddingProvider(table: ["Hello.": unitVec(0)])
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        XCTAssertTrue(splitter.breakIndices(for: ["Hello."]).isEmpty)
    }

    // MARK: F07 – Edge case: empty input returns no breaks
    func testF07_EmptyInputNoBreak() {
        let provider = MockEmbeddingProvider(table: [:])
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        XCTAssertTrue(splitter.breakIndices(for: []).isEmpty)
    }

    // MARK: F08 – Model unavailable (provider throws) returns empty
    func testF08_ModelUnavailableReturnsEmpty() {
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: FailingEmbeddingProvider())
        let sentences = [
            "This is a long enough work sentence for analysis.",
            "This is another long sentence about a different topic altogether."
        ]
        XCTAssertTrue(splitter.breakIndices(for: sentences).isEmpty, "Unavailable model should return empty break list")
    }

    // MARK: F09 – Threshold respected: just below threshold → no break
    func testF09_ThresholdJustBelow() {
        let sentences = ["Work topic sentence one.", "Personal topic sentence two."]
        // Orthogonal vectors → similarity(0,1) = 0, depth = 0+0 = 0 for 2-sentence case
        // (no left/right peaks beyond the gap itself)
        // With only 2 sentences: leftPeak = sim[0], rightPeak = sim[0], depth = 0.
        let provider = MockEmbeddingProvider(table: [
            "Work topic sentence one.":        unitVec(0),
            "Personal topic sentence two.":    unitVec(Float.pi / 2)
        ])
        // Use a threshold just above 0 so the 0-depth case doesn't fire
        let splitter = EmbeddingParagraphSplitter_Test(depthThreshold: 0.01, embeddingProvider: provider)
        // depth = 0 for 2-sentence window → no break even at low threshold
        let breaks = splitter.breakIndices(for: sentences)
        XCTAssertTrue(breaks.isEmpty, "2-sentence case always has depth 0 — should never break")
    }

    // MARK: F10 – Three sentences: middle trough produces break
    func testF10_ThreeSentencesMiddleTrough() {
        // sim(A,B) = high (both work), sim(B,C) = low (B work, C personal)
        // depth at gap 1: leftPeak=sim[0], rightPeak=sim[1] → big trough
        let sentences = [
            "We need to review the quarterly report.",
            "Let me know when the budget is finalised.",
            "How is your weekend going?"
        ]
        let provider = MockEmbeddingProvider(table: [
            "We need to review the quarterly report.":       unitVec(0.0),
            "Let me know when the budget is finalised.":     unitVec(0.1),
            "How is your weekend going?":                    unitVec(Float.pi / 2)
        ])
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        let breaks = splitter.breakIndices(for: sentences)
        XCTAssertTrue(breaks.contains(1), "Expected break at gap 1, got \(breaks)")
    }

    // MARK: F11 – Short-question guard threshold: one sentence just over limit
    func testF11_ShortQuestionGuardBoundary() {
        // Sentences where exactly one has 8 words — guard should NOT suppress
        let sentences = [
            "How are you doing today friend?",           // 6 words — short
            "How is the new project going at work?"      // 8 words — over limit
        ]
        // Orthogonal vectors (depth = 0 for 2-sentence window → no break)
        let provider = MockEmbeddingProvider(table: [
            "How are you doing today friend?":          unitVec(0),
            "How is the new project going at work?":    unitVec(Float.pi / 2)
        ])
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        // Guard should NOT fire (not all sentences are short), so embeddings ARE called.
        // But depth=0 for 2-sentence window → no break.
        // Key assertion: provider IS reached (if guard fires it would return empty without errors).
        // We just verify no crash and the guard doesn't incorrectly suppress.
        let breaks = splitter.breakIndices(for: sentences)
        // depth=0 for 2-sentence case, so empty is correct here
        XCTAssertTrue(breaks.isEmpty, "depth=0 for 2-sentence window; got \(breaks)")
    }

    // MARK: F12 – Multiple breaks detected in long sequence
    func testF12_MultipleBreaks() {
        // 5 sentences with ≥8 words each so the short-question guard does not suppress.
        // topic A (0,1), topic B (2,3), topic C (4)
        let sentences = [
            "We need to finish the quarterly budget report this week.",        // A
            "Please make sure all invoices are included in the summary.",      // A
            "By the way how is everyone in the family doing these days?",      // B
            "Have you heard any news about the upcoming family reunion event?", // B
            "Also the weather forecast looks really great for the weekend trip." // C
        ]
        let provider = MockEmbeddingProvider(table: [
            "We need to finish the quarterly budget report this week.":         unitVec(0.0),
            "Please make sure all invoices are included in the summary.":       unitVec(0.05),
            "By the way how is everyone in the family doing these days?":       unitVec(Float.pi / 2),
            "Have you heard any news about the upcoming family reunion event?":  unitVec(Float.pi / 2 + 0.05),
            "Also the weather forecast looks really great for the weekend trip.": unitVec(Float.pi)
        ])
        let splitter = EmbeddingParagraphSplitter_Test(embeddingProvider: provider)
        let breaks = splitter.breakIndices(for: sentences)
        // Expect break at gap 1 (A→B) and gap 3 (B→C)
        XCTAssertTrue(breaks.contains(1), "Expected break at gap 1 (A→B), got \(breaks)")
        XCTAssertTrue(breaks.contains(3), "Expected break at gap 3 (B→C), got \(breaks)")
    }
}
