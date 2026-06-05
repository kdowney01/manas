#!/usr/bin/env python3
"""
Creates a minimal EmotionClassifier.mlpackage stub for iOS development.
The stub always returns near-neutral probabilities so FacialEmotionAnalyzer
can run end-to-end without the real MAANAS model.

Run on macOS with Python 3.9–3.11:
    pip install coremltools
    python3 make_stub_model.py --output ../Manas/Resources/EmotionClassifier.mlpackage

Replace with the real model (convert_emotion_model.py) before any pilot testing.
"""

import argparse
import sys
from pathlib import Path

EMOTION_CLASSES = ["neutral", "happy", "sad", "angry", "fearful", "disgusted", "surprised"]


def make_stub(output_path: Path) -> None:
    try:
        import coremltools as ct
        from coremltools.models.neural_network import NeuralNetworkBuilder
        import numpy as np
    except ImportError:
        sys.exit("Run: pip install coremltools numpy")

    # Build a minimal pipeline: image input → fixed softmax output
    # Always returns neutral=0.70, others=0.05 (sum=1.0)
    fixed_probs = [0.70, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]

    input_features  = [("input",  ct.proto.FeatureTypes_pb2.FeatureType())]
    output_features = [("output", ct.proto.FeatureTypes_pb2.FeatureType())]

    builder = NeuralNetworkBuilder(
        input_features=[("input", [3, 224, 224])],
        output_features=[("output", [7])],
        mode="classifier",
    )

    # Single inner-product layer with fixed weights → always same output
    weights = np.zeros((7, 3 * 224 * 224), dtype=np.float32)
    bias    = np.array(fixed_probs, dtype=np.float32)
    builder.add_inner_product(
        name="stub_fc",
        W=weights, b=bias,
        input_channels=3 * 224 * 224,
        output_channels=7,
        has_bias=True,
        input_name="input_flat",
        output_name="output",
    )
    builder.add_flatten(name="flatten", input_name="input", output_name="input_flat")
    builder.set_class_labels(EMOTION_CLASSES)

    spec = builder.spec
    model = ct.models.MLModel(spec)
    model.short_description = "MANAS emotion classifier STUB — for development only"
    model.version = "0.0-stub"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    model.save(str(output_path))
    print(f"✓ Stub model saved to {output_path}")
    print("  ⚠️  This is a development stub. Replace with the real model before pilot.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    make_stub(args.output)
