# MANAS iOS App — Architecture

## System Context

The iOS app is one of three client surfaces in the MANAS platform:

```
┌─────────────────────────────────────────────────────┐
│                   Client Layer                      │
│  ┌──────────────┐  ┌────────────┐  ┌────────────┐  │
│  │  iOS App     │  │ React Web  │  │  WatchOS   │  │
│  │  (this repo) │  │  (webapp/) │  │  (MaanasW) │  │
│  └──────┬───────┘  └─────┬──────┘  └─────┬──────┘  │
└─────────┼────────────────┼───────────────┼──────────┘
          │                │               │
          └────────────────┼───────────────┘
                           │ REST / WebSocket
          ┌────────────────▼────────────────────────────┐
          │           Backend (FastAPI)                  │
          │  ┌──────────┐ ┌───────────┐ ┌────────────┐  │
          │  │Socket.IO │ │ REST Auth │ │ LLM Proxy  │  │
          │  └────┬─────┘ └─────┬─────┘ └─────┬──────┘  │
          └───────┼─────────────┼─────────────┼──────────┘
                  │             │             │
          ┌───────▼─────────────┼─────────────┼──────────┐
          │     MAANAS AI Engine (Python)      │          │
          │  ┌──────────┐ ┌──────────┐ ┌──────▼───────┐  │
          │  │ FACS     │ │  ONNX    │ │  rPPG        │  │
          │  │ Rules    │ │  Neural  │ │  Processor   │  │
          │  └────┬─────┘ └────┬─────┘ └──────┬───────┘  │
          │       └────────────▼───────────────┘          │
          │              WLOP Fusion Engine               │
          └────────────────────────────────────────────────┘
```

## iOS App Architecture

### Signal Sources

| Signal | iOS API | Notes |
|--------|---------|-------|
| Facial emotion | AVFoundation + Vision | Front camera, FACS landmarks via VNFaceObservationRequest |
| Heart rate / HRV | HealthKit | HKQuantityTypeIdentifier.heartRate, .heartRateVariabilitySDNN |
| rPPG (camera-based) | AVFoundation | Green channel analysis, fallback when HealthKit unavailable |
| App usage patterns | DeviceActivity (Screen Time API) | Requires FamilyControls entitlement |
| Sleep data | HealthKit | HKCategoryTypeIdentifier.sleepAnalysis |
| Steps / activity | HealthKit + CoreMotion | Activity level as behavioral signal |
| Microphone / speech | AVFoundation + Speech | Optional, opt-in, on-device only |

### App Layers

```
┌──────────────────────────────────────────────┐
│                  Presentation                │
│  SwiftUI views, navigation, notifications    │
├──────────────────────────────────────────────┤
│                  Domain                      │
│  Risk scoring, alert thresholds, user state  │
├──────────────────────────────────────────────┤
│                  Data                        │
│  HealthKit, DeviceActivity, CoreData, Keychain│
├──────────────────────────────────────────────┤
│                  AI / ML                     │
│  CoreML on-device + backend API bridge       │
├──────────────────────────────────────────────┤
│                  Infrastructure              │
│  Networking (REST + WebSocket), Auth (JWT)   │
└──────────────────────────────────────────────┘
```

### AI Inference Strategy

Two-tier approach:
1. **On-device (CoreML)** — lightweight models for always-on passive monitoring (low power, private)
2. **Backend (FastAPI + MAANAS engine)** — full ONNX + FACS + rPPG pipeline for deep analysis when app is active and connected

The iOS app handles graceful degradation: if network is unavailable, on-device inference continues.

### Privacy Architecture

- All raw biometric data processed on-device; only derived scores sent to backend
- No raw facial video stored or transmitted
- JWT-based auth; user controls all data sharing
- HealthKit data never leaves device without explicit consent
- DeviceActivity data aggregated locally before any reporting

### Key Frameworks

| Framework | Purpose |
|-----------|---------|
| SwiftUI | UI |
| HealthKit | Biometric data |
| AVFoundation | Camera + audio capture |
| Vision | Face landmark detection |
| CoreML | On-device ML inference |
| CoreMotion | Activity data |
| DeviceActivity | App usage (Screen Time) |
| FamilyControls | Entitlement for Screen Time |
| UserNotifications | Crisis alerts + check-ins |
| CryptoKit | Local encryption |
| Network | Connectivity monitoring |

### Backend Integration

The iOS app connects to the existing MAANAS FastAPI backend:
- **Auth**: `POST /api/auth/login` → JWT
- **Telemetry**: WebSocket `emit('telemetry_update', payload)` for continuous biometric scores
- **LLM Chat**: `POST /api/llm/chat` with emotion context injection
- **Risk Events**: `POST /api/risk/event` when threshold crossed

## Data Model (Core)

```swift
struct UserProfile {
    let id: UUID
    var baselineHRV: Double          // personalized baseline
    var baselineEmotionVector: [String: Double]
    var riskThresholds: RiskThresholds
}

struct BiometricSnapshot {
    let timestamp: Date
    let heartRate: Double?
    let hrv: Double?                 // RMSSD
    let emotionVector: [String: Double]  // 7-class probabilities
    let painScore: Double
    let stressIndex: Double
    let appUsageAnomaly: Bool
}

struct RiskEvent {
    let id: UUID
    let timestamp: Date
    let severity: RiskSeverity       // .low, .moderate, .high, .crisis
    let triggerSignals: [String]
    let interventionType: InterventionType
}
```

## Decisions Log

See [decisions/](../decisions/) for Architecture Decision Records (ADRs).
