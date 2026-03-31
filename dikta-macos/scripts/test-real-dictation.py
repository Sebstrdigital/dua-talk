#!/usr/bin/env python3
"""Test the formatter against REAL dictation patterns.

This script simulates what MessageFormatter + StructuredTextFormatter do,
using the same logic as the Swift production code, to validate against
real WhisperKit output patterns.

We're testing the LOGIC, not the Swift code directly. If this breaks,
the Swift code breaks the same way.
"""

# Replicate the core formatter logic in Python for testing
# This is NOT production code — it's a test harness

import re

# ============================================================
# Minimal formatter replication (matches Swift production logic)
# ============================================================

ABBREVIATIONS = {
    "Mr.", "Mrs.", "Ms.", "Dr.", "Prof.", "Jr.", "Sr.", "St.",
    "e.g.", "i.e.", "etc.", "vs.", "approx.", "dept.", "govt.", "corp."
}

def split_sentences(text):
    sentences = []
    current = ""
    chars = list(text)
    i = 0
    while i < len(chars):
        current += chars[i]
        if chars[i] in ".!?":
            trimmed = current.strip()
            is_abbrev = any(trimmed.endswith(a) for a in ABBREVIATIONS)
            if not is_abbrev:
                sentences.append(trimmed)
                current = ""
        i += 1
    leftover = current.strip()
    if leftover:
        sentences.append(leftover)
    return sentences


# ============================================================
# Test cases — REAL dictation patterns
# ============================================================

TESTS = [
    # === YOUR ACTUAL DICTATION SAMPLES ===
    {
        "name": "REAL-1: Your latest dictation (sparse punctuation)",
        "input": "Hi Reyno! How is everything? I wanted to talk to you about our project Where we go from here, whats highest priority and when you have time for a meeting Okay, thats all Best regards Sebastian",
        "expected_issues": [
            "Only 3 sentences detected (!, ?, then one giant run-on)",
            "Body is one long sentence — no paragraph splitting possible",
            "'Okay, thats all' buried in run-on — not extractable as closing",
            "'Best regards Sebastian' buried in run-on — sign-off extraction may fail",
        ]
    },
    {
        "name": "REAL-2: Your earlier dictation (well punctuated)",
        "input": "Hello, Reino! So, we have some work to do I guess. There is three things that I want to go through. First things first, there is a new document that we need to take a look at. Second thing, I have some feedback regarding a code review. And the third thing, we need to set a date for when we're going to start working. Okay, so how is life? How are you? How is my mom? Any news about the new car? Okay, have a good day. Best regards, Sebastian.",
        "expected_issues": [
            "Should split into work paragraph + personal paragraph",
            "Should detect numbered items (first, second, third)",
        ]
    },
    {
        "name": "REAL-3: Meeting + personal (problem case)",
        "input": "Hi Reino! So we need to have a new meeting where we can discuss the project and how to move forward. Can you have time tomorrow for a meeting at 4 o'clock? PM? How's the family? Is everything okay? Are you preparing for the Easter festivities? How's your health? Everything good? Okay that's all. Best regards, Sebastian.",
        "expected_issues": [
            "Paragraph break needed between 'PM?' and 'How's the family?'",
            "'Okay that's all' should be closing pleasantry",
        ]
    },

    # === SIMULATED WHISPER OUTPUT PATTERNS ===
    {
        "name": "WHISPER-1: Zero punctuation run-on",
        "input": "I wanted to reach out about the project we discussed last week I think we should schedule a call to go over the requirements and make sure we are aligned on the timeline",
        "expected_issues": [
            "Entire text is ONE sentence (no punctuation to split on)",
            "Formatter returns input unchanged — no formatting possible",
        ]
    },
    {
        "name": "WHISPER-2: Short casual, no punctuation",
        "input": "hey just checking in on that thing we talked about let me know when you have a minute",
        "expected_issues": [
            "One sentence, no formatting possible",
        ]
    },
    {
        "name": "WHISPER-3: Run-on with conjunctions",
        "input": "I woke up and I had coffee and then I went to the gym and after that I sat down to work and I got through most of my emails",
        "expected_issues": [
            "One sentence despite being 5 independent clauses",
            "'and then' chain detection requires the text to be split first",
        ]
    },
    {
        "name": "WHISPER-4: Question without question mark",
        "input": "did you get a chance to look at the document I sent over",
        "expected_issues": [
            "No question mark — treated as statement",
            "One sentence, no formatting possible",
        ]
    },
    {
        "name": "WHISPER-5: Partial punctuation (commas only)",
        "input": "So I finished the first draft, I think it looks good, but there are a few sections that need more work, can you take a look at it tomorrow",
        "expected_issues": [
            "Commas but no periods — one giant sentence",
            "Should ideally be 2-3 sentences",
        ]
    },
    {
        "name": "WHISPER-6: Mixed work + personal, some punctuation",
        "input": "so about the meeting tomorrow I think we should move it to Thursday because I have a conflict. Also how are the kids doing I heard they started a new school",
        "expected_issues": [
            "Only one period — splits into 2 sentences",
            "Second sentence has no period at end",
            "'Also' should trigger topic shift paragraph break",
        ]
    },
    {
        "name": "WHISPER-7: List dictation, natural markers",
        "input": "There are three things we need to discuss. First the budget is way over what we estimated. Second the timeline needs to be extended by two weeks. And third we need to hire another developer.",
        "expected_issues": [
            "Should detect 'first', 'second', 'third' as list markers",
            "Should format as numbered list",
        ]
    },
    {
        "name": "WHISPER-8: List dictation, no punctuation",
        "input": "there are three things we need to do first update the database second fix the login bug and third deploy to staging",
        "expected_issues": [
            "ONE sentence — no punctuation at all",
            "List markers present but no sentence boundaries",
            "Formatter cannot detect lists without sentence splitting first",
        ]
    },
    {
        "name": "WHISPER-9: Greeting variations",
        "input": "Hey John, hope you're doing well. Just wanted to let you know that the project is on track. We should be done by Friday. Talk to you soon. Cheers, Mike",
        "expected_issues": [
            "Greeting: 'Hey John,'",
            "Opening pleasantry: 'hope you're doing well'",
            "Sign-off: 'Cheers, Mike'",
        ]
    },
    {
        "name": "WHISPER-10: Email with colon-list",
        "input": "Hi team. Here are the action items from today's meeting: update the roadmap, schedule the design review, and send the client proposal. Please have these done by Wednesday. Thanks, Sarah",
        "expected_issues": [
            "Should detect colon-list pattern",
            "Should format items as bullets",
        ]
    },
]

# ============================================================
# Run analysis
# ============================================================

print("=" * 80)
print("REAL DICTATION FORMATTER ANALYSIS")
print("=" * 80)

total_issues = 0

for test in TESTS:
    name = test["name"]
    text = test["input"]
    expected = test["expected_issues"]

    sentences = split_sentences(text)

    print(f"\n--- {name} ---")
    print(f"INPUT ({len(text)} chars): {text[:100]}{'...' if len(text) > 100 else ''}")
    print(f"SENTENCES ({len(sentences)}):")
    for i, s in enumerate(sentences):
        preview = s[:80] + "..." if len(s) > 80 else s
        print(f"  [{i}] {preview}")

    # Analyze problems
    problems = []
    if len(sentences) <= 1:
        problems.append("FATAL: Only 1 sentence — formatter cannot do anything")
    if len(sentences) == 2:
        problems.append("WARNING: Only 2 sentences — very limited formatting")

    # Check for run-on sentences (>30 words without punctuation)
    for i, s in enumerate(sentences):
        word_count = len(s.split())
        if word_count > 25:
            problems.append(f"RUN-ON: Sentence [{i}] has {word_count} words")

    # Check if sign-off is detectable
    last_words = text.split()[-10:]
    last_area = " ".join(last_words).lower()
    sign_off_phrases = ["best regards", "kind regards", "cheers", "thanks", "sincerely"]
    sign_off_found = any(p in last_area for p in sign_off_phrases)
    if sign_off_found:
        # Check if it's in the last sentence or buried in a run-on
        last_sentence_words = len(sentences[-1].split()) if sentences else 0
        if last_sentence_words > 15:
            problems.append(f"BURIED SIGN-OFF: Sign-off phrase in last sentence but sentence has {last_sentence_words} words")

    if not problems:
        problems.append("OK — formatter should handle this well")

    print(f"ANALYSIS:")
    for p in problems:
        print(f"  {'!!' if 'FATAL' in p or 'RUN-ON' in p else '  '} {p}")
        total_issues += 1

    print(f"EXPECTED ISSUES:")
    for e in expected:
        print(f"     {e}")

print(f"\n{'=' * 80}")
print(f"SUMMARY: {len(TESTS)} tests, {total_issues} issues found")
print(f"\nBREAKDOWN:")

fatal = sum(1 for t in TESTS for s in split_sentences(t["input"]) if len(split_sentences(t["input"])) <= 1)
print(f"  FATAL (1 sentence, formatter useless): {fatal}/{len(TESTS)}")

runons = sum(1 for t in TESTS for s in split_sentences(t["input"]) if len(s.split()) > 25)
print(f"  Tests with run-on sentences (>25 words): {runons}")

good = sum(1 for t in TESTS if len(split_sentences(t["input"])) >= 3)
print(f"  Tests with 3+ sentences (formatter can work): {good}/{len(TESTS)}")
