# MANAS — Scripts

## Emotion Model Conversion

### Production: convert_emotion_model.py

Converts `emotion_model.onnx` from the MAANAS AI engine into `EmotionClassifier.mlpackage`
for on-device CoreML inference.

**Requires:** macOS, Python 3.9–3.11, coremltools, onnx, onnxruntime

```bash
pip install coremltools onnx onnxruntime
python3 convert_emotion_model.py \
    --input  /path/to/maanas/models/emotion_model.onnx \
    --output ../Manas/Resources/EmotionClassifier.mlpackage
```

After conversion, add `EmotionClassifier.mlpackage` to the Xcode target:
- File → Add Files to "Manas" → select the `.mlpackage`
- Ensure "Add to target: Manas" is checked

### Development stub: make_stub_model.py

Creates a minimal stub model that always returns near-neutral probabilities.
Lets `FacialEmotionAnalyzer` run end-to-end during development without the real model.

```bash
pip install coremltools numpy
python3 make_stub_model.py \
    --output ../Manas/Resources/EmotionClassifier.mlpackage
```

⚠️ Replace with the real model before any pilot or demo.

## Model Contract

The iOS app (`FacialEmotionAnalyzer.swift`) expects:

| Property | Value |
|----------|-------|
| Input name | `input` |
| Input type | Image or MultiArray Float32 (1, 3, 224, 224) |
| Output: class label | `classLabel` — String |
| Output: probabilities | `classProbability` — Dictionary\<String, Double\> |
| Classes | neutral, happy, sad, angry, fearful, disgusted, surprised |
| Preprocessing | Normalize pixel values to [-1, 1] |
| Deployment target | iOS 17+ |
