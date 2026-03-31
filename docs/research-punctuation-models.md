# Punctuation Restoration Models — Research (2026-03-31)

Goal: offline token-classification model for restoring . , ? ! in ASR output.
Constraints: <200 MB ideal, CoreML (macOS) + ONNX (Windows), <200 ms for 50-100 words.

---

## Model Comparison

| # | Model | Base arch | Model weight size | Punctuation marks | Languages | Period F1 | Comma F1 | Question F1 | Exclaim F1 | ONNX available? | Notes |
|---|-------|-----------|-------------------|-------------------|-----------|-----------|----------|-------------|------------|-----------------|-------|
| 1 | **1-800-BAD-CODE/punctuation_fullstop_truecase_english** | Custom 6-layer Transformer (dim 512) | **200 MB** (ONNX) | . , ? + ACRONYM | EN only | 0.92 | 0.82 | 0.83 | N/A | **YES — ships as ONNX** | Also does true-casing + sentence segmentation. SentencePiece tokenizer (32k vocab). Trained on news. |
| 2 | **kredor/punctuate-all** | xlm-roberta-**base** | **1059 MB** (PyTorch) | . , ? - : | 12 langs (EN DE FR ES BG IT PL NL CZ PT SK SL) | 0.95 | 0.86 | 0.86 | N/A | No (but convertible) | Most-downloaded (608k/mo). Based on oliverguhr's work but smaller base model. |
| 3 | **oliverguhr/fullstop-punctuation-multilingual-base** | xlm-roberta-**base** | **1059 MB** (PyTorch) | . , ? - : | 5 langs (EN DE FR IT NL) | 0.95 | 0.85 | 0.87 | N/A | No (but convertible) | Same base arch as kredor but fewer languages. |
| 4 | **oliverguhr/fullstop-punctuation-multilang-large** | xlm-roberta-**large** | **2132 MB** (PyTorch) | . , ? - : | 4 langs (EN DE FR IT) | 0.95 | 0.82 | 0.89 | N/A | Yes (2132 MB) | Too large. Reference quality benchmark. |
| 5 | **felflare/bert-restore-punctuation** | bert-base-uncased | **416 MB** (PyTorch) | . , ? ! : ; ' - + Upper | EN only | 0.75 | 0.55 | 0.51 | 0.24 (!) | No (but convertible) | Does true-casing. Trained on Yelp reviews. **Poor quality** — comma/question F1 far below others. |
| 6 | **1-800-BAD-CODE/xlm-roberta_punctuation_fullstop_truecase** | xlm-roberta-**base** | **1061 MB** (ONNX) | . , ? + ACRONYM | **47 languages** | Not published per-lang | — | — | N/A | **YES — ships as ONNX** | Massive language coverage. Same architecture as #1 but XLM-R backbone. |

### Key size notes
- xlm-roberta-base = 278M parameters = ~1059 MB fp32 / **~530 MB fp16** / **~265 MB int8**
- xlm-roberta-large = 560M parameters = ~2132 MB fp32 (too large)
- bert-base-uncased = 110M parameters = ~416 MB fp32 / **~208 MB fp16** / **~104 MB int8**
- 1-800-BAD-CODE English = custom 6-layer = ~50M parameters = **200 MB ONNX** (already optimized)

---

## Analysis

### Winner: 1-800-BAD-CODE/punctuation_fullstop_truecase_english

**This is the clear best fit for Dikta.** Reasons:

1. **Already ships as ONNX** (200 MB) — no conversion needed for Windows
2. **Custom small architecture** — 6 layers, dim 512, SentencePiece tokenizer. Purpose-built for this task
3. **Does three things in one pass**: punctuation + true-casing + sentence segmentation
4. **F1 scores are strong**: period 0.92, comma 0.82, question 0.83
5. **200 MB** fits the size budget perfectly
6. **SentencePiece tokenizer** (not WordPiece/BPE) — simpler to port
7. **Active maintainer** with a `punctuators` pip package that uses the ONNX model directly

**Limitations:**
- English only (no multilingual — but Dikta's formatter is English-focused)
- No exclamation mark prediction (predicts . , ? only + ACRONYM class)
- Trained on news data — may be weaker on casual/dictation speech patterns

### Runner-up: kredor/punctuate-all

If multilingual is needed later:
- xlm-roberta-base at ~1059 MB fp32, but **quantizable to ~265 MB int8**
- 12 languages including all Dikta languages
- Higher F1 on period (0.95) and comma (0.86)
- Would need ONNX conversion (straightforward via `optimum` library)
- Also no exclamation mark

### Avoid: felflare/bert-restore-punctuation

Despite being the only model that predicts exclamation marks, its quality is unacceptably poor (comma F1 0.55, question F1 0.51, exclamation F1 0.24).

---

## The Missing Exclamation Mark Problem

**None of the high-quality models predict exclamation marks.** This is because:
- Training data (Europarl, news) has very few exclamations
- In formal text, exclamations are rare
- ASR output almost never implies exclamation vs. period

**Options:**
1. Skip exclamation prediction (just use . , ?) — pragmatic, matches what good models do
2. Post-process: detect exclamation-indicating words ("wow", "amazing", "great") and swap period to !
3. Fine-tune one of the models to add ! class — would need labeled data

---

## CoreML Conversion Path

For macOS (CoreML), the path is:
1. **1-800-BAD-CODE model**: ONNX -> CoreML via `coremltools` (`ct.converters.convert(onnx_model)`)
2. **XLM-R models**: PyTorch -> ONNX via `optimum` -> CoreML via `coremltools`

The 1-800-BAD-CODE model is simplest because it already has the ONNX, and at 200 MB the CoreML conversion should produce a similar-sized mlmodel/mlpackage.

**Important:** The SentencePiece tokenizer must also be handled natively. On macOS, SentencePiece has a C++ library that can be called from Swift. On Windows, there are .NET bindings.

---

## Input Pattern Test

Example: "I wanted to talk to you about our project Where we go from here whats highest priority and when you have time for a meeting Okay thats all Best regards Sebastian"

These models handle **lowercase unpunctuated text** — that is exactly what they are designed for. The 1-800-BAD-CODE model explicitly takes lowercase input and also restores capitalization. WhisperKit typically outputs capitalized text with no punctuation, so you would need to lowercase before feeding to the model (trivial).

The above example would likely produce something like:
"I wanted to talk to you about our project. Where we go from here, what's highest priority, and when you have time for a meeting. Okay, that's all. Best regards, Sebastian."

Note: "whats" -> the model won't add apostrophes (except felflare, poorly). Contraction restoration is a separate problem.

---

## Fine-tuning a Tiny Model — Assessment

**Practical but probably unnecessary.** Here is the analysis:

| Approach | Base model | Size | Training data needed | Effort |
|----------|-----------|------|---------------------|--------|
| DistilBERT fine-tune | distilbert-base (66M params) | ~260 MB fp32 / ~130 MB fp16 | 500k-1M sentences | 2-3 days work |
| TinyBERT fine-tune | TinyBERT-6L (67M params) | ~260 MB fp32 / ~130 MB fp16 | 500k-1M sentences | 2-3 days work |
| MobileBERT fine-tune | MobileBERT (25M params) | ~100 MB fp32 / ~50 MB fp16 | 500k-1M sentences | 2-3 days work |

Training data sources: TED talks transcripts, LibriSpeech, Common Voice (all have punctuated ground truth).

**Verdict:** The 1-800-BAD-CODE model at 200 MB already hits the sweet spot. Fine-tuning only makes sense if:
- You need exclamation marks badly
- You need <100 MB model size
- You need domain-specific (dictation/email) accuracy

---

## Recommendation

**Phase 1 (ship it):** Use `1-800-BAD-CODE/punctuation_fullstop_truecase_english`
- 200 MB ONNX ready for Windows
- Convert to CoreML for macOS (~200 MB mlpackage)
- Predicts . , ? + capitalization + sentence boundaries
- Fast inference (small model, <200ms easily for 100 words)

**Phase 2 (if needed):** Add exclamation marks via post-processing rules or fine-tune

**Phase 3 (if needed):** Switch to quantized kredor/punctuate-all for multilingual support (~265 MB int8)
