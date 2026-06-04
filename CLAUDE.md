# MANAS iOS App — Claude Context

## What This Project Is

MANAS (Multimodal AI for Awareness, Neurocognitive Analysis & Support) is an iOS app that passively monitors users for early signs of mental health deterioration using biometrics, behavioral signals, and AI. It is the mobile-first pilot deliverable (P2) of the MIT CTO Program Impact Project.

See `docs/PROJECT_OVERVIEW.md` for full context.

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI (HIG light-mode, Montserrat brand font)
- **AI (on-device):** CoreML (converted from ONNX — pending)
- **AI (backend):** MAANAS FastAPI engine (Python, ONNX + FACS + rPPG)
- **Key Frameworks:** HealthKit, UserNotifications, MessageUI, AVFoundation, Vision, CoreML, DeviceActivity, FamilyControls
- **Min iOS:** 17.0

## Key Docs

- `docs/PROJECT_OVERVIEW.md` — vision, team, impact targets
- `docs/architecture/ARCHITECTURE.md` — system design
- `docs/requirements/REQUIREMENTS.md` — functional and non-functional requirements
- `docs/decisions/` — Architecture Decision Records
- `docs/history/PROJECT_HISTORY.md` — project timeline
- `docs/ui-mocks.html` — v0.3 UI mockups (open in browser)

## What's Built

### Core / Security
- `Core/Security/SecureStorage.swift` — Keychain wrapper, AES-256 key, file protection
- `Core/Notifications/AlertManager.swift` — local notifications; .high nudge, .crisis escalation
- `Core/Models/EmergencyContact.swift` — model + Keychain-backed store
- `Core/DesignSystem/BrandColors.swift` + `Typography.swift` — brand tokens

### HealthKit & Risk
- `Core/HealthKit/HealthKitManager.swift` — HR, HRV, sleep, steps; background delivery
- `Core/RiskScoring/RiskScoringEngine.swift` — weighted scoring, 7-day calibration, fires AlertManager + BackendService

### Backend & AI
- `Core/Backend/BackendService.swift` — JWT auth, REST + WebSocket to MAANAS; cert-pinning stub
- `Core/AI/CompanionService.swift` — 6 doctor personas; on-device keyword fallback; backend LLM bridge
- `Core/DeviceActivity/DeviceActivityMonitor.swift` — stub; needs FamilyControls entitlement

### Features
- `App/ManasApp.swift` — wires all services; Montserrat nav bar; notification categories
- `App/RootView.swift` — TabView (Today / Companion / Settings) + CrisisView fullScreenCover
- `Features/Onboarding/OnboardingView.swift` — 4-step: Welcome → HealthKit → Emergency Contacts → Notifications → Calibration
- `Features/Dashboard/DashboardView.swift` — wellness ring, biometric bento, insight card, alerts
- `Features/Companion/CompanionView.swift` — chat UI with persona picker
- `Features/Crisis/CrisisView.swift` — 988, emergency SMS, companion link
- `Features/Settings/SettingsView.swift` — contacts CRUD, data export/delete, privacy

## Critical Constraints

1. **HIPAA compliance required** — no raw biometric values in logs, notifications, or backend payloads; only derived scores transmitted
2. **No raw biometric data ever leaves the device without explicit user consent**
3. **No raw facial video stored or transmitted at any time**
4. **App must function fully offline** (on-device CoreML fallback)
5. **Keychain for all sensitive storage** — never UserDefaults for PHI-adjacent data
6. **DeviceActivity / FamilyControls entitlements** require Apple developer provisioning + approval
7. **iOS 17+ required** for latest DeviceActivity APIs
8. **HealthKit background delivery** must be enabled in entitlements
9. **BAA required** with MAANAS backend operator before PHI-adjacent data is transmitted

## Open Items

- [ ] CoreML model: convert `emotion_model.onnx` → `EmotionClassifier.mlpackage` using coremltools
- [ ] Add Montserrat .ttf files to `Manas/Resources/Fonts/` and register in Xcode target
- [ ] FamilyControls entitlement: request Apple approval for DeviceActivity
- [ ] Certificate pinning: implement SHA-256 hash pinning in `BackendService.swift`
- [ ] Add SocketIO-Client-Swift via SPM for Socket.IO telemetry protocol
- [ ] Implement FR-2: facial emotion analysis (AVFoundation + VNFaceObservationRequest + CoreML)
- [ ] Add `Manas.entitlements` entries for HealthKit background + FamilyControls

## MIT Course Alignment

This project must conform to MIT Professional Education CTO Program standards. Architecture decisions should be defensible using technology roadmapping (MOT) frameworks. Portfolio decomposition: this app = P2 deliverable.
