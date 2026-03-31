#!/usr/bin/env python3
"""
Convert all-MiniLM-L12-v2 from HuggingFace to CoreML (.mlpackage).

Strategy:
  1. Download model via HuggingFace transformers
  2. Export with torch.export (ATEN dialect) + .run_decompositions({})
     — required for coremltools 8+ with torch 2.x
  3. Convert ExportedProgram → CoreML with int8 weight quantisation
  4. The model outputs a normalised 384-dim sentence embedding directly

Prerequisites:
    pip install torch transformers coremltools

Usage:
    python3 scripts/convert-minilm-coreml.py

Output:
    dikta-macos/Dikta/Resources/MiniLML12v2.mlpackage
    dikta-macos/Dikta/Resources/minilm-vocab.txt
"""

import os
import sys
import shutil
import numpy as np

OUTPUT_DIR = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "dikta-macos",
    "Dikta",
    "Resources",
))
MLPACKAGE_NAME = "MiniLML12v2.mlpackage"
VOCAB_NAME = "minilm-vocab.txt"
MODEL_ID = "sentence-transformers/all-MiniLM-L12-v2"
MAX_SEQ_LEN = 128


def check_deps():
    missing = []
    for pkg in ["torch", "transformers", "coremltools"]:
        try:
            __import__(pkg)
        except ImportError:
            missing.append(pkg)
    if missing:
        print(f"ERROR: Missing packages: {', '.join(missing)}")
        print("Install with: pip install torch transformers coremltools")
        sys.exit(1)


def cosine_np(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))


def convert():
    check_deps()

    import torch
    import torch.nn as nn
    import torch.nn.functional as F
    from torch.export import export
    import coremltools as ct
    from transformers import AutoTokenizer, AutoModel

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # ------------------------------------------------------------------ #
    # 1. Download tokenizer + model                                        #
    # ------------------------------------------------------------------ #
    print(f"Downloading {MODEL_ID} …")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    # attn_implementation="eager" disables SDPA for a cleaner export graph
    model = AutoModel.from_pretrained(MODEL_ID, attn_implementation="eager")
    model.eval()

    assert model.config.hidden_size == 384, f"Unexpected hidden size: {model.config.hidden_size}"
    print(f"  Hidden size: {model.config.hidden_size}  Layers: {model.config.num_hidden_layers}")

    # ------------------------------------------------------------------ #
    # 2. Save vocab.txt                                                    #
    # ------------------------------------------------------------------ #
    vocab_dst = os.path.join(OUTPUT_DIR, VOCAB_NAME)
    saved = tokenizer.save_vocabulary(OUTPUT_DIR)
    for p in saved:
        if p and p.endswith("vocab.txt") and p != vocab_dst:
            shutil.move(p, vocab_dst)
            break
    if not os.path.exists(vocab_dst):
        vocab = tokenizer.get_vocab()
        with open(vocab_dst, "w", encoding="utf-8") as f:
            for token, _ in sorted(vocab.items(), key=lambda x: x[1]):
                f.write(token + "\n")
    print(f"  Vocab: {vocab_dst} ({sum(1 for _ in open(vocab_dst))} tokens)")

    # ------------------------------------------------------------------ #
    # 3. Wrap model: (input_ids, attention_mask) → normalised [1, 384]    #
    # ------------------------------------------------------------------ #
    class MiniLMEmbedder(nn.Module):
        def __init__(self, backbone):
            super().__init__()
            self.backbone = backbone

        def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
            outputs = self.backbone(input_ids=input_ids, attention_mask=attention_mask)
            token_embeddings = outputs.last_hidden_state       # [1, seq, 384]
            mask = attention_mask.unsqueeze(-1).float()         # [1, seq, 1]
            pooled = (token_embeddings * mask).sum(1) / mask.sum(1).clamp(min=1e-9)
            return F.normalize(pooled, p=2, dim=1)             # [1, 384]

    wrapper = MiniLMEmbedder(model)
    wrapper.eval()

    # ------------------------------------------------------------------ #
    # 4. Export with torch.export (ATEN dialect, then decompose)          #
    # ------------------------------------------------------------------ #
    print("\nExporting with torch.export …")
    enc = tokenizer(
        "Hello world",
        return_tensors="pt",
        padding="max_length",
        truncation=True,
        max_length=MAX_SEQ_LEN,
    )
    input_ids = enc["input_ids"]
    attention_mask = enc["attention_mask"]

    with torch.no_grad():
        exported = export(wrapper, (input_ids, attention_mask))
    # coremltools requires ATEN dialect (not TRAINING)
    exported = exported.run_decompositions({})
    print(f"  Dialect: {exported.dialect}")

    # Verify exported output matches original
    with torch.no_grad():
        out_exported = exported.module()(input_ids, attention_mask)
        out_orig = wrapper(input_ids, attention_mask)
    fidelity_export = cosine_np(out_exported[0].numpy(), out_orig[0].numpy())
    print(f"  Export fidelity: {fidelity_export:.6f} (must be > 0.9999)")
    assert fidelity_export > 0.9999

    # ------------------------------------------------------------------ #
    # 5. Convert ExportedProgram → CoreML                                 #
    # ------------------------------------------------------------------ #
    print("\nConverting to CoreML …")
    mlmodel = ct.convert(
        exported,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, MAX_SEQ_LEN), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, MAX_SEQ_LEN), dtype=np.int32),
        ],
        outputs=[
            ct.TensorType(name="sentence_embedding", dtype=np.float32),
        ],
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.macOS13,
        convert_to="mlprogram",
    )

    # Int8 weight quantisation to reduce bundle size
    try:
        from coremltools.optimize.coreml import (
            OpLinearQuantizerConfig,
            OptimizationConfig,
            linear_quantize_weights,
        )
        mlmodel = linear_quantize_weights(
            mlmodel,
            config=OptimizationConfig(
                global_config=OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8")
            ),
        )
        print("  Applied int8 weight compression")
    except Exception as e:
        print(f"  Compression skipped: {e}")

    # Metadata
    mlmodel.short_description = (
        "all-MiniLM-L12-v2 sentence embeddings (384-dim, L2-normalised). "
        "Cosine similarity of outputs equals semantic similarity."
    )
    mlmodel.input_description["input_ids"] = (
        f"WordPiece token IDs [1, {MAX_SEQ_LEN}], zero-padded"
    )
    mlmodel.input_description["attention_mask"] = (
        f"Attention mask [1, {MAX_SEQ_LEN}], 1=real token 0=padding"
    )
    mlmodel.output_description["sentence_embedding"] = (
        "L2-normalised sentence embedding, shape [1, 384]"
    )

    # ------------------------------------------------------------------ #
    # 6. Save                                                              #
    # ------------------------------------------------------------------ #
    out_path = os.path.join(OUTPUT_DIR, MLPACKAGE_NAME)
    if os.path.exists(out_path):
        shutil.rmtree(out_path)
    mlmodel.save(out_path)

    total_bytes = sum(
        os.path.getsize(os.path.join(dp, f))
        for dp, _, files in os.walk(out_path)
        for f in files
    )
    mb = total_bytes / 1024 / 1024
    print(f"  Saved: {out_path} ({mb:.1f} MB)")
    if mb > 40:
        print(f"  WARNING: {mb:.1f} MB exceeds the 40 MB budget")

    # ------------------------------------------------------------------ #
    # 7. Verify saved CoreML model                                         #
    # ------------------------------------------------------------------ #
    print("\nVerifying saved CoreML model …")
    loaded = ct.models.MLModel(out_path)

    def cml_embed(text: str) -> np.ndarray:
        enc2 = tokenizer(
            text, return_tensors="np",
            padding="max_length", truncation=True, max_length=MAX_SEQ_LEN,
        )
        pred = loaded.predict({
            "input_ids": enc2["input_ids"].astype(np.int32),
            "attention_mask": enc2["attention_mask"].astype(np.int32),
        })
        e = pred["sentence_embedding"]
        return e[0] if e.ndim == 2 else e

    def pt_embed(text: str) -> np.ndarray:
        enc2 = tokenizer(
            text, return_tensors="pt",
            padding="max_length", truncation=True, max_length=MAX_SEQ_LEN,
        )
        with torch.no_grad():
            out = wrapper(enc2["input_ids"], enc2["attention_mask"])
        return out[0].numpy()

    sentences = [
        "The cat sat on the mat.",
        "A feline rested on the rug.",
        "The quarterly results were disappointing.",
    ]
    cml_embs = [cml_embed(s) for s in sentences]
    pt_embs = [pt_embed(s) for s in sentences]

    # Semantic ordering check
    sim_01 = cosine_np(cml_embs[0], cml_embs[1])
    sim_02 = cosine_np(cml_embs[0], cml_embs[2])
    print(f"  Cat/feline: {sim_01:.4f}  Cat/quarterly: {sim_02:.4f}")
    assert sim_01 > sim_02, "Semantic ordering wrong — similar pair should score higher"
    print("  Semantic ordering check PASSED")

    # Acceptance criterion: CoreML vs PyTorch cosine > 0.99
    fidelity = cosine_np(cml_embs[0], pt_embs[0])
    print(f"  CoreML vs PyTorch fidelity: {fidelity:.6f}")
    if fidelity >= 0.99:
        print("  Fidelity check PASSED (> 0.99)")
    else:
        print(f"  WARNING: fidelity {fidelity:.4f} below 0.99")

    print("\nConversion complete.")
    print(f"  Model:  {out_path}  ({mb:.1f} MB)")
    print(f"  Vocab:  {vocab_dst}")
    print(f"\n  Output: 'sentence_embedding' [1, 384] — L2-normalised, use directly in Swift.")


if __name__ == "__main__":
    convert()
