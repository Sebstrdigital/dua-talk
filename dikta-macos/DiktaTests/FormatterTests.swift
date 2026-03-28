/// FormatterTests — Unit tests for the formatter helpers.
///
/// Since the main Dikta target is an executable (not a library), we duplicate
/// the helper functions here. If you change the production code, update these too.
///
/// Run via: cd dikta-macos && swift test

import XCTest

// MARK: - Inlined production functions (mirrors Formatter/TextHelpers.swift)

private let abbreviations: Set<String> = [
    "Mr.", "Mrs.", "Ms.", "Dr.", "Prof.", "Jr.", "Sr.", "St.",
    "e.g.", "i.e.", "etc.", "vs.", "approx.", "dept.", "govt.", "corp."
]

private func isFragment(_ sentence: String) -> Bool {
    if sentence.count <= 2 && sentence.hasSuffix(".") { return true }
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

    for prefix in ["and ", "or ", "but "] {
        if result.lowercased().hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
            break
        }
    }

    if result.hasSuffix(".") {
        result = String(result.dropLast())
    }

    result = result.prefix(1).uppercased() + result.dropFirst()

    return result.trimmingCharacters(in: .whitespaces)
}

func findPreamble(_ sentences: [String], beforeIndex: Int) -> String? {
    if beforeIndex <= 0 { return nil }
    let preamble = sentences[0..<beforeIndex].joined(separator: " ")
    return preamble
}

// MARK: - splitSentences Tests

class SplitSentencesTests: XCTestCase {

    func testSimpleTwoSentences() {
        XCTAssertEqual(splitSentences("Hello. World."), ["Hello.", "World."])
    }

    func testAbbreviation() {
        XCTAssertEqual(
            splitSentences("Dr. Smith went home. He was tired."),
            ["Dr. Smith went home.", "He was tired."]
        )
    }

    func testMixedPunctuation() {
        XCTAssertEqual(
            splitSentences("What? Really! Yes."),
            ["What?", "Really!", "Yes."]
        )
    }

    func testDecimalNumber() {
        XCTAssertEqual(
            splitSentences("Version 1.0 is out. Update now."),
            ["Version 1.0 is out.", "Update now."]
        )
    }

    func testEllipsis() {
        XCTAssertEqual(
            splitSentences("She said hello... Then she left."),
            ["She said hello...", "Then she left."]
        )
    }

    func testSingleSentence() {
        XCTAssertEqual(splitSentences("One sentence."), ["One sentence."])
    }

    func testEmptyString() {
        XCTAssertEqual(splitSentences(""), [])
    }

    func testWhitespaceOnly() {
        XCTAssertEqual(splitSentences("   "), [])
    }

    func testNoPeriod() {
        XCTAssertEqual(splitSentences("No period at the end"), ["No period at the end"])
    }

    func testCommonAbbreviations() {
        XCTAssertEqual(
            splitSentences("Check e.g. the docs. Then proceed."),
            ["Check e.g. the docs.", "Then proceed."]
        )
    }

    func testInitials() {
        XCTAssertEqual(
            splitSentences("J. K. Rowling wrote Harry Potter. It sold millions."),
            ["J. K. Rowling wrote Harry Potter.", "It sold millions."]
        )
    }
}

// MARK: - trimItem Tests

class TrimItemTests: XCTestCase {

    func testBasicTrim() {
        XCTAssertEqual(trimItem("  buy milk.  "), "Buy milk")
    }

    func testLeadingAnd() {
        XCTAssertEqual(trimItem("and fix the bug."), "Fix the bug")
    }

    func testLeadingOr() {
        XCTAssertEqual(trimItem("or skip this step."), "Skip this step")
    }

    func testLeadingBut() {
        XCTAssertEqual(trimItem("but not this one."), "Not this one")
    }

    func testKeepsQuestionMark() {
        XCTAssertEqual(trimItem("is it ready?"), "Is it ready?")
    }

    func testKeepsExclamation() {
        XCTAssertEqual(trimItem("wow!"), "Wow!")
    }

    func testAlreadyCapitalized() {
        XCTAssertEqual(trimItem("Already capitalized."), "Already capitalized")
    }

    func testEmptyAfterTrim() {
        XCTAssertEqual(trimItem("  "), "")
    }
}

// MARK: - findPreamble Tests

class FindPreambleTests: XCTestCase {

    func testPreambleExists() {
        XCTAssertEqual(
            findPreamble(["We need three things.", "Buy milk.", "Buy eggs."], beforeIndex: 1),
            "We need three things."
        )
    }

    func testNoPreamble() {
        XCTAssertNil(findPreamble(["Buy milk.", "Buy eggs.", "Buy bread."], beforeIndex: 0))
    }

    func testMultiSentencePreamble() {
        XCTAssertEqual(
            findPreamble(["Intro one.", "Intro two.", "First item.", "Second item."], beforeIndex: 2),
            "Intro one. Intro two."
        )
    }
}
