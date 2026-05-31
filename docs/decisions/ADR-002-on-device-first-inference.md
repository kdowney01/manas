# ADR-002: On-Device-First AI Inference

**Date:** 2026-05-31  
**Status:** Accepted

## Context

The MAANAS AI engine runs on a Python FastAPI backend using ONNX, FACS rules, and rPPG. We must decide how much inference happens on-device vs. server-side for the iOS app.

## Decision

**On-device inference by default; backend as optional enhancement.**

- CoreML models handle always-on passive monitoring (lightweight emotion + HRV stress scoring)
- Backend MAANAS engine used when app is foregrounded and network available (full ONNX + FACS + WLOP pipeline)
- Backend use is opt-in for users who want higher accuracy

## Rationale

1. **Privacy** — raw biometric data and facial video must never leave the device by default
2. **Battery** — always-on background inference must be power-efficient; CoreML is ANE-accelerated
3. **Offline resilience** — mental health monitoring must work without internet
4. **Trust** — users are more likely to adopt an app that demonstrably keeps data local

## ONNX → CoreML Conversion

The existing `emotion_model.onnx` from the MAANAS engine will be converted to CoreML using `coremltools`:
```python
import coremltools as ct
model = ct.converters.onnx.convert(model='emotion_model.onnx')
model.save('EmotionClassifier.mlpackage')
```

## Tradeoffs

- On-device CoreML model will be less accurate than full ONNX + FACS + rPPG pipeline
- Requires maintaining two model versions (ONNX for backend, CoreML for device)

## Consequence

App ships with embedded CoreML models. Backend connection is a premium/optional feature. All risk scoring logic must have an on-device fallback path.
