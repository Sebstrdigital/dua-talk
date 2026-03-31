#!/usr/bin/env python3
"""Test MiniLM and GTE-tiny sentence embeddings for paragraph splitting."""

import numpy as np
from sentence_transformers import SentenceTransformer
import time

# Same test messages as the Swift NLEmbedding test
TEST_MESSAGES = [
    ("Test 1 — Reino work+personal", [
        "Hello, Reino!",
        "So, we have some work to do I guess.",
        "There is three things that I want to go through.",
        "First things first, there is a new document that we need to take a look at.",
        "Second thing, I have some feedback regarding a code review.",
        "And the third thing, we need to set a date for when we're going to start working.",
        "Okay, so how is life?",
        "How are you?",
        "How is my mom?",
        "Any news about the new car?",
        "Okay, have a good day.",
        "Best regards, Sebastian.",
    ]),
    ("Test 2 — Reino meeting+personal (PROBLEM CASE)", [
        "Hi Reino!",
        "So we need to have a new meeting where we can discuss the project and how to move forward.",
        "Can you have time tomorrow for a meeting at 4 o'clock?",
        "PM?",
        "How's the family?",
        "Is everything okay?",
        "Are you preparing for the Easter festivities?",
        "How's your health?",
        "Everything good?",
        "Okay that's all.",
        "Best regards, Sebastian.",
    ]),
    ("Test 3 — Pure work (no shift expected)", [
        "We need to update the database schema before Friday.",
        "The migration script is ready but needs testing.",
        "I also updated the API endpoints to match the new schema.",
        "Please review the pull request when you get a chance.",
    ]),
    ("Test 4 — Pure personal (no shift expected)", [
        "How are you doing?",
        "How's the family?",
        "Are the kids enjoying school?",
        "Did you end up getting that new car you were looking at?",
    ]),
]

MODELS = [
    ("all-MiniLM-L6-v2", "sentence-transformers/all-MiniLM-L6-v2"),
    ("gte-tiny", "thenlper/gte-small"),  # gte-tiny doesn't exist on HF, gte-small is closest small one
]

# Also try the actual tiny models
MODELS = [
    ("all-MiniLM-L6-v2 (22MB, 384-dim)", "sentence-transformers/all-MiniLM-L6-v2"),
    ("gte-small (67MB, 384-dim)", "thenlper/gte-small"),
    ("all-MiniLM-L12-v2 (33MB, 384-dim)", "sentence-transformers/all-MiniLM-L12-v2"),
]


def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))


def compute_depth_scores(similarities):
    """Depth score: how much similarity drops at each gap relative to neighbors."""
    depths = []
    for i in range(len(similarities)):
        left = max(similarities[i - 1], similarities[i]) if i > 0 else similarities[i]
        right = max(similarities[i], similarities[i + 1]) if i < len(similarities) - 1 else similarities[i]
        depth = (left - similarities[i]) + (right - similarities[i])
        depths.append(depth)
    return depths


def run_test(model_name, model_id):
    print(f"\n{'=' * 80}")
    print(f"MODEL: {model_name}")
    print(f"{'=' * 80}")

    t0 = time.time()
    model = SentenceTransformer(model_id)
    print(f"  Loaded in {time.time() - t0:.1f}s, dim={model.get_sentence_embedding_dimension()}")

    for test_name, sentences in TEST_MESSAGES:
        print(f"\n  {test_name}")
        print(f"  {'-' * 60}")

        # Encode all sentences
        t0 = time.time()
        embeddings = model.encode(sentences)
        encode_time = (time.time() - t0) * 1000

        # Compute adjacent similarities
        similarities = []
        for i in range(len(sentences) - 1):
            sim = cosine_similarity(embeddings[i], embeddings[i + 1])
            similarities.append(float(sim))

        # Compute depth scores
        depths = compute_depth_scores(similarities)

        # Print sentences
        for i, s in enumerate(sentences):
            preview = s[:67] + "..." if len(s) > 70 else s
            print(f"    [{i}] {preview}")

        # Print similarities
        print(f"\n    Adjacent similarities ({encode_time:.0f}ms encode time):")
        for i in range(len(similarities)):
            sim = similarities[i]
            depth = depths[i]
            bar = "█" * int(sim * 30)
            marker = f" ◄◄ BREAK (depth={depth:.3f})" if depth > 0.15 else ""
            print(f"    [{i}]→[{i+1}]  sim={sim:.3f}  depth={depth:.3f}  {bar}{marker}")

        # Summary
        breaks = [(i, d) for i, d in enumerate(depths) if d > 0.15]
        breaks.sort(key=lambda x: -x[1])
        if not breaks:
            print(f"\n    → No breaks suggested")
        else:
            labels = [f"[{i}] (depth {d:.3f})" for i, d in breaks]
            print(f"\n    → Breaks after: {', '.join(labels)}")

        # For Test 2, highlight the critical gap
        if "PROBLEM" in test_name:
            print(f"\n    *** CRITICAL: [3]→[4] 'PM?' → 'How's the family?' depth = {depths[3]:.3f} {'✅ DETECTED' if depths[3] > 0.15 else '❌ MISSED'}")


if __name__ == "__main__":
    for name, model_id in MODELS:
        run_test(name, model_id)

    print(f"\n{'=' * 80}")
    print("DONE — compare models above")
