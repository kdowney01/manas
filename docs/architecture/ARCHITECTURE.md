# MANAS iOS App — Architecture

## System Context

The iOS app is one of three client surfaces in the MANAS platform:

```
┌──────────────────────────────────────────────────────────────┐
│                        Client Layer                          │
│  ┌──────────────┐   ┌────────────┐   ┌────────────────────┐ │
│  │  iOS App     │   │ React Web  │   │  WatchOS (MaanasW) │ │
│  │  (this repo) │   │  (webapp/) │   │                    │ │
│  └──────┬───────┘   └─────┬──────┘   └────────┬───────────┘ │
└─────────┼─────────────────┼────────────────────┼─────────────┘
          │                 │                    │
          │ native WS       │ Socket.IO          │ Socket.IO
          │ /ws/telemetry   │                    │
          └─────────────────┼────────────────────┘
                            │ REST / WebSocket
          ┌─────────────────▼────────────────────────────────┐
          │              Backend (FastAPI)                    │
          │  ┌──────────────┐ ┌───────────┐ ┌────────────┐  │
          │  │ WS /ws/*     │ │ REST Auth │ │ LLM Proxy  │  │
          │  │ Socket.IO    │ │           │ │            │  │
          │  └──────┬───────┘ └─────┬─────┘ └─────┬──────┘  │
          └─────────┼───────────────┼──────────────┼──────────┘
                    │               │              │
          ┌─────────▼───────────────┼──────────────┼──────────┐
          │         MAANAS AI Engine (Python)                  │
          │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
          │  │ FACS     │  │  ONNX    │  │  rPPG Processor  │ │
          │  │ Rules    │  │  Neural  │  │                  │ │
          │  └────┬─────┘  └────┬─────┘  └──────┬───────────┘ │
          │       └─────────────▼────────────────┘             │
          │                WLOP Fusion Engine                   │
          └─────────────────────────────────────────────────────┘
```

> **Note on transport:** The iOS app uses native WebSocket (`URLSessionWebSocketTask`)
> to `/ws/telemetry?token=<jwt>` — a dedicated FastAPI endpoint that runs alongside
> the existing Socket.IO server. React and MaanasWatch continue using Socket.IO
> unchanged. See ADR-003.

## iOS App Architecture

### Signal Sources

| Signal | iOS API | Notes |
|--------|---------|-------|
| Heart rate / HRV | HealthKit | HKQuantityTypeIdentifier.heartRate, .heartRateVariabilitySDNN — background delivery |
| Sleep data | HealthKit | HKCategoryTypeIdentifier.sleepAnalysis |
| Steps / activity | HealthKit + CoreMotion | Activity level as behavioral signal |
| Facial emotion | AVFoundation + Vision + CoreML | Front camera, VNFaceLandmarks2D → FACSRuleEngine + EmotionClassifier.mlpackage |
| rPPG (camera-based) | AVFoundation | Green channel analysis; deferred to v2 on-device |
| App usage patterns | DeviceActivity (Screen Time API) | Requires FamilyControls entitlement — Apple approval pending |
| Microphone / speech | AVFoundation + Speech | Optional, opt-in, on-device only — deferred to v2 |

### App Layers

```
┌────────────────────────────────────────────────────────────┐
│                       Presentation                         │
│  SwiftUI views · TabView shell · Notifications · CrisisView│
├────────────────────────────────────────────────────────────┤
│                         Domain                             │
│  RiskScoringEngine · AlertManager · CompanionService       │
├────────────────────────────────────────────────────────────┤
│                          Data                              │
│  HealthKit · DeviceActivity · SecureStorage (Keychain)     │
├────────────────────────────────────────────────────────────┤
│                         AI / ML                            │
│  FacialEmotionAnalyzer · FACSRuleEngine · CoreML           │
├────────────────────────────────────────────────────────────┤
│                      Infrastructure                        │
│  BackendService (REST + native WS) · AppConfig · CryptoKit │
└────────────────────────────────────────────────────────────┘
```

### AI Inference Strategy

Two-tier approach:

1. **On-device (CoreML + FACS rules)** — always-on passive monitoring; low power; private.
   - `FacialEmotionAnalyzer`: AVFoundation → VNFaceLandmarks2D → FACSRuleEngine (symbolic AU mapping) + `EmotionClassifier.mlpackage` (when bundled)
   - `HealthKitManager`: HR, HRV, sleep, steps in background
   - `RiskScoringEngine`: weighted fusion of all on-device signals

2. **Backend (FastAPI + MAANAS engine)** — full ONNX + FACS + rPPG pipeline for deep analysis; opt-in when connected.

Graceful degradation: if network is unavailable, on-device inference continues uninterrupted.

### Privacy Architecture

- All raw biometric data processed on-device; only derived scores sent to backend
- No raw facial video stored or transmitted at any time
- JWT stored in Keychain (SecureStorage); user controls all data sharing
- HealthKit data never leaves device without explicit user consent
- DeviceActivity data aggregated locally; only anomaly flag reported
- Notification content contains no PHI (HIPAA)
- All Keychain entries use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

### Security Architecture

| Concern | Implementation |
|---------|----------------|
| Credential storage | Keychain via `SecureStorage` (AES-256 key, JWT, contacts) |
| Data encryption | `CryptoKit` SymmetricKey; `NSFileProtectionCompleteUnlessOpen` on disk |
| Transport security | TLS 1.2+ minimum; SHA-256 public-key cert pinning in `URLSessionDelegate` |
| Auth | Short-lived JWT; stored in Keychain; never logged |
| PHI in logs | `OSLog` with `.private` privacy level on all health-adjacent values |

### Key Frameworks

| Framework | Purpose |
|-----------|---------|
| SwiftUI | UI |
| HealthKit | Biometric data + background delivery |
| AVFoundation | Camera capture (facial emotion) |
| Vision | Face landmark detection (VNFaceLandmarks2D) |
| CoreML | On-device emotion classification |
| CoreMotion | Activity data |
| DeviceActivity | App usage monitoring (Screen Time — entitlement pending) |
| FamilyControls | Entitlement for DeviceActivity |
| UserNotifications | Crisis alerts + wellbeing nudges |
| MessageUI | Emergency contact SMS (MFMessageComposeViewController) |
| CryptoKit | Local encryption + cert pinning |

### Backend Integration

The iOS app connects to the MAANAS FastAPI backend via:

| Channel | Endpoint | Protocol | Purpose |
|---------|----------|----------|---------|
| Auth | `POST /api/auth/login` | HTTPS REST | JWT token exchange |
| Telemetry | `/ws/telemetry?token=<jwt>` | **Native WebSocket** | Continuous derived-score streaming |
| LLM Chat | `POST /api/llm/chat` | HTTPS REST | AI companion with emotion context |
| Risk Events | `POST /api/risk/event` | HTTPS REST | Threshold-crossing notification |

> **Transport note (ADR-003):** Telemetry uses `URLSessionWebSocketTask` with plain
> JSON payloads. The backend's Socket.IO server is unchanged; the `/ws/telemetry`
> endpoint is additive. JWT is passed as a query parameter (WebSocket headers have
> limited support). See `docs/decisions/ADR-003-native-websocket.md`.

### App Navigation Structure

```
App Launch
├── Onboarding (one-time, 5 steps)
│   Welcome → HealthKit → Emergency Contacts → Notifications → Calibration
└── Main App (TabView)
    ├── Tab 1: Today (Dashboard)
    │   Wellbeing ring · Biometric grid · AI insight · Recent alerts
    ├── Tab 2: Companion
    │   6 doctor personas · Chat · On-device fallback
    └── Tab 3: Settings
        Emergency contacts · Privacy · Export · Delete all

Overlays (any screen)
├── CrisisView (fullScreenCover) — triggered by .crisis risk event
└── Risk notifications (system banner) — triggered by AlertManager
```

## Data Model (Core)

```swift
struct BiometricSnapshot {
    let timestamp:        Date
    let heartRate:        Double?      // BPM
    let hrv:              Double?      // RMSSD in ms
    let restingHeartRate: Double?      // BPM
    let sleepHours:       Double?
    let stepCount:        Int?
    let emotionVector:    EmotionVector?  // 7-class probabilities from FacialEmotionAnalyzer
    var stressIndex:      StressIndex  // computed: physiological + facial fusion
}

struct EmotionVector {
    var neutral, happy, sad, angry, fearful, disgusted, surprised: Float
    var stressSignal: Float  // composite: fearful + angry + disgusted
}

struct UserProfile {
    var baselineHRV:          Double?
    var baselineRestingHR:    Double?
    var baselineSleepHours:   Double?
    var calibrationComplete:  Bool
    var riskThresholds:       RiskThresholds  // personalized from 7-day baseline
}

struct RiskEvent {
    let id:             UUID
    let timestamp:      Date
    let severity:       RiskSeverity   // .low | .moderate | .high | .crisis
    let triggerSignals: [String]       // human-readable, no raw PHI values
    let riskScore:      Double
}
```

## Risk Scoring Weights

| Signal | Weight | Notes |
|--------|--------|-------|
| HRV suppression | 40% | Strongest physiological stress marker |
| Heart rate elevation | 30% | Secondary physiological signal |
| Sleep deficit | 20% | Recovery and resilience indicator |
| Activity anomaly | 10% | Sudden behavioral change |
| Facial emotion stress | +15% | Additive when camera available |

Thresholds personalized from 7-day calibration baseline (population defaults until complete).

## Decisions Log

See [decisions/](../decisions/) for Architecture Decision Records:
- ADR-001: Swift + SwiftUI (native only)
- ADR-002: On-device-first AI inference
- ADR-003: Native WebSocket over Socket.IO
