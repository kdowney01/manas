# ADR-001: Use Swift + SwiftUI for iOS App

**Date:** 2026-05-31  
**Status:** Accepted

## Context

We need to choose a development stack for the MANAS iOS app. Options considered: Swift/SwiftUI (native), React Native, Flutter.

## Decision

Use **Swift + SwiftUI** natively.

## Rationale

1. **HealthKit + DeviceActivity require native entitlements** — both frameworks have deep OS integration that is unreliable or unsupported via cross-platform bridges
2. **CoreML performance** — native CoreML inference is significantly faster and more power-efficient than bridged equivalents
3. **Existing MaanasWatch codebase is Swift** — sharing code and patterns is simpler
4. **Vision framework** — facial landmark detection via VNFaceObservationRequest is native-only
5. **Background processing** — HealthKit background delivery and background app refresh are most reliable natively

## Tradeoffs

- Slower to build than React Native if team has React expertise
- No code sharing with React web frontend

## Consequence

All iOS app code will be Swift 5.9+ with SwiftUI. UIKit only used where SwiftUI has gaps (e.g., camera preview layers).
