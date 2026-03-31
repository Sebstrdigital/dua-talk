# Research: The Science of Paragraph Breaking

**Date:** 2026-03-31
**Purpose:** Determine whether deterministic (non-LLM) paragraph-splitting heuristics can handle topic-shift detection in dictated text, or whether this is inherently a semantic understanding problem.

---

## 1. Classical Composition Rules

### Strunk & White — *The Elements of Style*
**Rule 13: "Make the paragraph the unit of composition."**
- Begin each paragraph with a **topic sentence**; succeeding sentences explain, establish, or develop it.
- A subject requires subdivision into topics; each topic gets its own paragraph.
- The purpose is to **aid the reader** — paragraphs are a visual signal of structure.
- When a paragraph is part of a larger composition, its relation to what precedes may need a transition word/phrase in the topic sentence, or one or more introductory/transition sentences.

**Key insight:** Strunk & White define paragraphs by *topical unity* — one idea per paragraph. But the rules are descriptive ("a paragraph tends to..."), not algorithmic. There is no mechanical test for "has the topic changed?"

### Chicago Manual of Style (18th ed.)
- CMOS focuses on **formatting** (first-line indent, flush-left after extracts, no indent after section breaks) rather than *when* to break.
- Special rule: new paragraph when **changing speakers in dialogue**.
- No prescriptive rules for "break here when the topic changes" — it assumes the writer knows.

### AP Style / Business Writing
- Favors **short paragraphs** (1-3 sentences) for readability, especially in journalism and digital media.
- In business letters: conventionally 3 paragraphs minimum (intro/purpose, body/detail, conclusion/next steps).
- Email convention: blank line between paragraphs, 3-5 sentences max per paragraph, bold headings for scannability.

**Takeaway for Dikta:** Classical rules confirm that paragraphs mark **topic shifts** and **rhetorical function changes** (setup -> evidence -> conclusion). But they provide no algorithm — they assume a human writer making semantic judgments.

---

## 2. Discourse Analysis / Text Linguistics

### Halliday & Hasan — Cohesion Theory (1976)
**Book:** *Cohesion in English*

Five types of cohesion that bind text together:
1. **Reference** — pronouns, demonstratives ("he", "this", "the former")
2. **Substitution** — replacing an element ("one", "do so")
3. **Ellipsis** — omitting recoverable elements
4. **Conjunction** — logical connectors ("however", "therefore", "meanwhile")
5. **Lexical cohesion** — word repetition, synonyms, collocations, semantic fields

**Texture:** Text has "tight" texture (many cohesive ties) or "loose" texture (few ties). Paragraph boundaries tend to occur where texture loosens — where lexical chains end and new ones begin. A **chain return** (referring back to an earlier chain) signals a return to a previous topic.

**Relevance to Dikta:** Cohesion theory is the theoretical foundation for ALL computational approaches below. The key measurable signal is: when the vocabulary/entities shift, a paragraph boundary is likely.

### Rhetorical Structure Theory (RST) — Mann & Thompson (1988)
- Describes text as a **tree** of rhetorical relations (nucleus-satellite pairs).
- Relations include: elaboration, contrast, cause, condition, background, evaluation, etc.
- Text is segmented into **Elementary Discourse Units (EDUs)** — roughly clause-level.
- RST explains *why* parts of text relate, not just *where* boundaries are.

**Relevance to Dikta:** RST operates at clause/sentence level, not paragraph level. Useful conceptually (paragraphs group related EDUs), but requires deep parsing — not feasible as a lightweight heuristic.

### Discourse Markers / Cue Phrases
Research classifies discourse markers into:
- **Structural:** "first", "next", "finally", "to summarize"
- **Referential:** "because", "so", "as a result"
- **Cognitive:** "well", "you know", "I mean"
- **Interpersonal:** "honestly", "look", "by the way"

Key finding: **"Anyway"** marks a shift away from a topic. **"By the way"**, **"speaking of"**, **"on another note"** are strong topic-shift markers. Neural networks trained on cue words correctly categorized 90% of strong cue words as topic-shift vs. topic-internal (from Maschler's classification).

**Relevance to Dikta:** Cue phrase detection is one of the most reliable deterministic signals. A dictionary of ~50-100 discourse markers with shift/continuation labels would catch many explicit transitions.

---

## 3. Email / Letter Formatting Conventions

### Business Letter Structure (Purdue OWL, Wisconsin Writing Center)
- **Block format:** left-justified, single-spaced, blank line between paragraphs.
- Conventional structure: purpose paragraph -> detail paragraph(s) -> action/closing paragraph.
- Each paragraph addresses **one main point**.

### Email-Specific Rules
- Shorter paragraphs than letters (2-4 sentences).
- **Greeting** is its own block.
- **Sign-off** is its own block.
- Topic changes get their own paragraph.
- Questions are often grouped or get their own paragraph.
- Professional emails: one topic per email when possible; if multiple topics, each gets a paragraph with a clear transition.

### Informal/Personal Email Patterns
Common structure in real-world casual emails:
1. Greeting + pleasantry ("Hey! Hope you're doing well.")
2. Main business/topic ("About the project...")
3. Secondary topic if any ("Also, regarding...")
4. Personal/social ("How's the family?")
5. Sign-off ("Talk soon!")

**Relevance to Dikta:** The greeting, sign-off, and "also/by the way" transitions are detectable with rules. The shift from business to personal is the hard case — it often happens without any transition word.

---

## 4. Computational Approaches (Non-LLM)

### TextTiling — Hearst (1994, 1997)
**The foundational algorithm.** Three steps:
1. **Tokenization:** Split text into pseudo-sentences (token-sequences of k tokens). Remove stop words, stem remaining words.
2. **Similarity scoring:** Slide two adjacent windows across the text. At each gap between windows, compute **cosine similarity** of the term-frequency vectors of the two blocks. High similarity = same topic. Low similarity = topic shift.
3. **Boundary detection:** Compute **depth scores** at each valley in the similarity plot. Depth = how much lower this point is than its surrounding peaks. Place boundaries at valleys exceeding a threshold (mean - 1 SD of all depth scores).

**Requirements:** Works best on long expository text (1000+ words). Needs sufficient vocabulary in each window for statistical signal. Designed for **multi-paragraph** segments, not individual paragraph breaks.

### C99 — Choi (2000)
- Builds a **sentence-by-sentence similarity matrix** using cosine similarity of bag-of-words vectors.
- Converts to a **rank matrix** (each cell = how many neighbors have lower similarity) to improve contrast.
- Uses **divisive clustering** on the rank matrix diagonal to find optimal segment boundaries.
- More robust than TextTiling for shorter segments.

### LCseg — Galley et al. (2003)
- Extends TextTiling with **lexical chains** (sequences of repeated non-stop words).
- Weights chains by: number of words in chain + compactness (fewer sentences = more compact = higher weight).
- Computes cohesion at each sentence boundary using weighted chain overlap.
- Designed for **multiparty conversation** transcripts — closer to Dikta's domain than TextTiling.
- Performance: Pk = 15.31 on WSJ test corpus.

### TopicTiling — Riedl & Biemann (2012)
- TextTiling variant that replaces raw words with **LDA topic IDs**.
- Each word is assigned its most probable topic from a pre-trained LDA model.
- Similarity is computed between adjacent blocks of topic IDs instead of raw terms.
- **No smoothing or window size needed** (unlike TextTiling).
- Significant improvement: error rates 20x lower than TextTiling on standard benchmarks.
- Requires pre-trained LDA model (unsupervised, but needs a training corpus).

### Sentence Embedding + Cosine Similarity
- Modern variant: represent each sentence with **sentence-BERT** or similar embeddings.
- Compute cosine similarity between adjacent sentences.
- Place boundaries where similarity drops below threshold.
- Solbiati et al. (2021) showed this works significantly better than bag-of-words.
- **Not an LLM** (uses a fixed embedding model), but requires a neural model at inference time.

### Other Approaches
- **BayesSeg** (Eisenstein & Barzilay, 2008): Bayesian model for topic segmentation, generative.
- **GraphSeg** (Glavaš et al., 2016): Graph-based, uses semantic relatedness graphs.
- **Supervised models:** BiLSTM, BERT-based classifiers trained on labeled data. MiniSeg (Retkowski & Waibel, 2025) is a compact supervised model that achieves state-of-the-art on paragraph segmentation for speech transcripts.

### Evaluation Metrics
- **Pk** (Beeferman et al., 1999): Probability of disagreement at distance k. Lower = better.
- **WindowDiff** (Pevzner & Hearst, 2002): Improved version of Pk, penalizes false positives and misses equally.
- **F1 on boundary detection:** Precision/recall of predicted boundaries vs. reference.
- **Boundary Similarity (BS):** More recent metric accounting for near-misses.

---

## 5. The Specific Problem: Dictated Messages

### The Challenge
Given a stream of 5-15 dictated sentences in a message/email context, detect topic shifts like:
- Work discussion -> personal questions ("How's the family?")
- One subject -> different subject without explicit transition words

### What Works Deterministically

| Signal | Feasibility | Reliability |
|--------|-------------|-------------|
| **Cue phrases** ("by the way", "also", "anyway", "speaking of") | Easy to implement | High — but only catches ~30-40% of topic shifts |
| **Question clustering** (group consecutive questions) | Easy | Medium — questions often span topics |
| **Greeting/sign-off detection** | Easy (regex) | Very high for those specific zones |
| **Sentence-length heuristics** (very short sentence after long ones) | Easy | Low — too many false positives |
| **Lexical overlap** (Jaccard similarity between adjacent sentences) | Medium | Low for short texts — vocabulary too sparse |
| **Named entity shift** (different people/places/projects mentioned) | Medium (needs NER) | Medium — entities don't always change at boundaries |
| **Rhetorical function shift** (statement -> question, assertion -> request) | Medium | Medium — helps with some patterns |

### What Doesn't Work Without Semantics

| Signal | Why It Fails |
|--------|-------------|
| **TextTiling / C99 / LCseg** | Designed for 1000+ word documents. A 5-15 sentence message has too little vocabulary for statistical lexical cohesion to work. Window sizes would encompass the entire message. |
| **LDA / TopicTiling** | Topic models need substantial text per segment. A 2-3 sentence paragraph doesn't have enough words to assign a stable topic distribution. |
| **Word overlap between adjacent sentences** | In a short message, adjacent sentences about different topics may share common words ("I", "we", "the", "think"). Conversely, same-topic sentences may use entirely different vocabulary ("The deadline is Friday. We need to submit the report." — zero content word overlap but same topic). |

### The Core Problem

The shift from "Let's schedule the meeting for Thursday" to "How are the kids doing?" is detectable by:
- Cue phrase ("By the way, how are the kids?") -> YES, deterministic
- No cue phrase ("How are the kids doing?") -> Requires understanding that "meeting scheduling" and "children's wellbeing" are different semantic domains

This is the **distributional semantics gap**. Without understanding what words *mean*, you cannot detect that "meeting" and "Thursday" belong to a different topic than "kids" and "doing." Even sentence embeddings (which are not pure rules) struggle here because the sentences are too short for reliable similarity scoring.

### What the Research Says

The 2025 paper by Retkowski & Waibel (*Paragraph Segmentation Revisited*) is the most directly relevant work. Key findings:
- Even their compact MiniSeg model (a small neural net, not an LLM) only achieves **F1 of ~50%** on paragraph segmentation of speech transcripts.
- LLM-based approaches (GPT-4, etc.) perform better but still have systematic mismatches with human judgment.
- The paper explicitly notes that **prosodic cues** (pauses, pitch, intonation) from audio could improve segmentation but are not yet used.
- The paper acknowledges this is an **underexplored problem** — paragraph segmentation of speech transcripts has no established benchmarks before their work.

---

## 6. Verdict: Feasibility Assessment

### What You Can Build Deterministically (and should)
1. **Zone-based rules** (greeting, sign-off, salutation detection) — already in Dikta's formatter
2. **Cue phrase dictionary** (~50-100 transition phrases that signal topic shifts)
3. **Rhetorical function shifts** (statement -> question, or request -> social pleasantry)
4. **Sentence count heuristics** (break after N sentences as a fallback)

### What You Cannot Build Without Semantic Understanding
- Detecting unmarked topic shifts in short text (the "meeting -> kids" problem)
- Distinguishing elaboration (same topic, different angle) from topic change
- Understanding that "The budget looks good. Sarah did a great job." is one topic, while "The budget looks good. The weather's been nice." is two

### The Honest Answer
**You have likely reached the ceiling of what pure rules can do for paragraph splitting in short dictated messages.** The classical algorithms (TextTiling, C99, LCseg) were designed for documents 10-100x longer than a dictated email. Lexical cohesion statistics simply don't work on 5-15 sentences. The only deterministic signals that reliably work at this scale are cue phrases and structural patterns (greetings, questions, sign-offs) — which your formatter already captures.

The next meaningful improvement requires **semantic understanding** — at minimum a sentence embedding model (not a full LLM, but a neural model like sentence-BERT), and ideally an LLM for the hardest cases. The recent research (MiniSeg, 2025) confirms that even purpose-built neural models only achieve ~50% F1 on this task.

---

## Sources

### Style Guides & Composition
- Strunk & White, *The Elements of Style* (Rule 13: paragraph unity)
- Chicago Manual of Style, 18th ed. (Section 2.12: paragraph formatting)
- Purdue OWL, "The Basic Business Letter"
- Wisconsin Writing Center, "Business Letter Format"

### Discourse Analysis
- Halliday & Hasan, *Cohesion in English* (1976) — cohesion taxonomy
- Mann & Thompson, "Rhetorical Structure Theory" (1988) — RST framework
- Maschler, discourse marker classification (interpersonal/referential/structural/cognitive)

### Computational Text Segmentation
- Hearst, "TextTiling: Segmenting Text into Multi-paragraph Subtopic Passages" (1997) — [ACL Anthology](https://aclanthology.org/J97-1003.pdf)
- Choi, "C99: Advances in domain independent linear text segmentation" (2000)
- Galley et al., "Discourse Segmentation of Multi-Party Conversation" (2003) — LCseg — [Columbia NLP](http://www.cs.columbia.edu/nlp/papers/2003/galley_al_03.pdf)
- Riedl & Biemann, "TopicTiling: A Text Segmentation Algorithm based on LDA" (2012) — [ACL Anthology](https://aclanthology.org/W12-3307/)
- Solbiati et al., sentence-BERT for topic segmentation (2021)

### Speech-Specific Paragraph Segmentation
- Retkowski & Waibel, "Paragraph Segmentation Revisited: Towards a Standard Task for Structuring Speech" (2025) — [arXiv](https://arxiv.org/html/2512.24517) — TEDPara benchmark, MiniSeg model

### Surveys
- AssemblyAI, "Text Segmentation - Approaches, Datasets, and Evaluation Metrics" (2021) — [Blog](https://www.assemblyai.com/blog/text-segmentation-approaches-datasets-and-evaluation-metrics)
- "Recent Trends in Linear Text Segmentation: A Survey" (2024) — [ACL Findings](https://aclanthology.org/2024.findings-emnlp.174.pdf)
