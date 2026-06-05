#!/usr/bin/env python3
"""
MANAS — Emotion Model Conversion Script
Converts emotion_model.onnx (from the MAANAS AI engine) to EmotionClassifier.mlpackage
for on-device CoreML inference on iOS 17+.

Requirements (run on macOS with Python 3.9–3.11):
    pip install coremltools onnx onnxruntime

Usage:
    python3 convert_emotion_model.py \
        --input  /path/to/maanas/models/emotion_model.onnx \
        --output /path/to/manas/Manas/Resources/EmotionClassifier.mlpackage

After conversion, add EmotionClassifier.mlpackage to the Xcode target:
    File → Add Files to "Manas" → select EmotionClassifier.mlpackage
    Ensure "Add to target: Manas" is checked.

Model contract (must match FacialEmotionAnalyzer.swift):
    Input:  "input" — MultiArray Float32 (1, 3, 224, 224)  [NCHW, normalized to [-1,1]]
    Output: "classLabel" — String (dominant class label)
            "classProbability" — Dictionary<String, Double> (7-class softmax)
    Classes: neutral, happy, sad, angry, fearful, disgusted, surprised
"""

import argparse
import sys
from pathlib import Path

EMOTION_CLASSES = ["neutral", "happy", "sad", "angry", "fearful", "disgusted", "surprised"]


def convert(input_path: Path, output_path: Path) -> None:
    try:
        import coremltools as ct
    except ImportError:
        sys.exit("coremltools not found. Run: pip install coremltools onnx onnxruntime")

    print(f"Loading ONNX model from {input_path} ...")

    # Convert ONNX → CoreML
    model = ct.convert(
        str(input_path),
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS17,
        inputs=[
            ct.ImageType(
                name="input",
                shape=(1, 3, 224, 224),
                color_layout=ct.colorlayout.RGB,
                bias=[-1.0, -1.0, -1.0],
                scale=1.0 / 127.5,
            )
        ],
        classifier_config=ct.ClassifierConfig(EMOTION_CLASSES),
    )

    # Metadata
    model.short_description = "MANAS 7-class facial emotion classifier (MAANAS ONNX → CoreML)"
    model.author = "Kinshuk Dutta / MANAS Team"
    model.version = "1.0"
    model.input_description["input"] = "224×224 RGB face crop, normalized to [-1, 1]"
    model.output_description["classLabel"] = "Dominant emotion class"
    model.output_description["classProbability"] = "Softmax probabilities for all 7 classes"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    model.save(str(output_path))
    print(f"✓ Saved to {output_path}")

    # Quick sanity check
    print("\nModel spec:")
    print(f"  Input:   {model.input_description}")
    print(f"  Output:  {model.output_description}")
    print(f"  Classes: {EMOTION_CLASSES}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert MAANAS ONNX emotion model to CoreML")
    parser.add_argument("--input",  required=True, type=Path, help="Path to emotion_model.onnx")
    parser.add_argument("--output", required=True, type=Path, help="Output .mlpackage path")
    args = parser.parse_args()

    if not args.input.exists():
        sys.exit(f"Input not found: {args.input}")
    if not args.input.suffix == ".onnx":
        sys.exit("Input must be a .onnx file")

    convert(args.input, args.output)
