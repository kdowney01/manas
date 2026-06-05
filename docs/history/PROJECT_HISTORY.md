# MANAS — Project History

## 2025-06-17 — MIT CTO Program begins
Kyle Downey enrolls in MIT Professional Education Blended Certificate: Chief Technology Officer program (12 months, 5 courses + 2 residential weeks).

## 2025-08-11 — Team Manas forms
CTO Cohort Group 2 forms: Daniel Gumucio (CEO), Sunita Gogineni (VP IT), Blair Day (SVP Engineering), Kyle Downey (VP Engineering), Kinshuk Dutta (Director AI Product). Team name "Manas" chosen (Sanskrit: "mind").

## 2025-09-10 — Problem Statement submitted (v1)
First version of Impact Project problem statement submitted. Establishes the core thesis: proactive mental health monitoring via multimodal AI, always-on, privacy-first.

## 2025-09-23 — Problem Statement resubmitted
Revised and resubmitted after instructor feedback from Claudio. Added conceptual design, measurable impact targets, evaluation approach, and tech linkage. Received strong positive feedback.

## 2025-10 — Technical development begins
Kinshuk Dutta leads development of the MAANAS AI engine: hybrid neuro-symbolic architecture combining FACS rules + ONNX neural networks + rPPG cardiac telemetry. MaanasWatch (WatchOS app) started.

## 2025-12 — Strategy & Portfolio Analysis course (MOT)
Team develops R&D portfolio decomposing MANAS into 5 fundable projects (P1–P5), total $15.2M over ~18 months. P2 (MVP mobile pilot app) identified as priority.

## 2026-03-02 — R&D Portfolio Assignment submitted
Final R&D portfolio presentation submitted for MOT: Strategy & Portfolio Analysis course.

## 2026-05-31 — iOS App development starts
Kyle Downey initializes `manas` repo on GitHub. iOS app development begins as the P2 mobile-first pilot deliverable. Technical blueprints from Kinshuk Dutta imported as reference.

Foundation built: ManasApp, RootView, OnboardingView (3-step), HealthKitManager (HR/HRV/sleep/steps/background delivery), RiskScoringEngine (weighted scoring, 7-day calibration, RiskEvent generation), BiometricSnapshot, UserProfile, RiskThresholds, RiskEvent/RiskSeverity.

## 2026-06-01 — Design system, branding, and full MVP feature build

### Design system
- Brand colors applied (Indigo Blue #5c6cb3, Lavender #ad6cad, Soft Mint #a8e6cf, Warm Peach #ffb397, Cool Gray #f4f4f7) per branding guidelines deck
- Typography system: Montserrat across all weights; UINavigationBarAppearance wired in ManasApp
- BrandColors.swift + Typography.swift created; Info.plist updated with UIAppFonts
- App tint set to brand indigo via `.tint(.manasPrimary)` + UINavigationBar appearance

### UI Mockups (docs/ui-mocks.html)
- v0.1: initial dark-mode 4-screen mockup
- v0.2: rebuilt with HIG light mode + brand colors + actual Montserrat font
- v0.3: major redesign incorporating award-winning health app UI patterns (Oura Ring wellness ring, Calm gradient welcome, Bearable insight card, WHOOP metric hierarchy). Actual logo embedded (PNG with transparent background processed via Pillow flood-fill).
- DashboardView rebuilt: wellness score ring (SVG arc), bento biometric grid with trend arrows, Daily Insight card, greeting header

### Logo
- `manas_logo_sm.png` uploaded to `Manas/Resources/`
- White background removed via Python/Pillow flood-fill → `Manas/Resources/Assets/manas_logo.png` (RGBA transparent)
- SVG approximation also created at `Manas/Resources/Assets/manas-logo.svg`

### MVP features built (2026-06-01 session)
All features from REQUIREMENTS.md FR-4 through FR-7 implemented:

**Security / HIPAA foundation:**
- `Core/Security/SecureStorage.swift` — Keychain R/W, AES-256 encryption key, NSFileProtection helper. All sensitive data (JWT, emergency contacts, user profile) stored in Keychain. Raw PHI never stored or logged.
- OSLog used throughout with `.private` privacy level for any health-adjacent values.

**Notifications & Crisis (FR-4, FR-7):**
- `Core/Notifications/AlertManager.swift` — UNUserNotificationCenter; gentle nudge at .high, critical alert at .crisis. Notification content contains no raw biometric values (HIPAA).
- `Features/Crisis/CrisisView.swift` — 988 call + text, emergency contact SMS via MessageUI, AI companion link. Presented as fullScreenCover from RootView on `.crisis` event.

**Emergency contacts (FR-7):**
- `Core/Models/EmergencyContact.swift` + `EmergencyContactStore` — Keychain-backed CRUD.
- Emergency contact step added to onboarding (Step 2 of 4).

**Backend integration (FR-5):**
- `Core/Backend/BackendService.swift` — JWT auth (Keychain), REST + URLSessionWebSocketTask telemetry to MAANAS FastAPI. Certificate pinning stub in place. Only derived scores transmitted (never raw biometrics).
- Socket.IO note: needs SocketIO-Client-Swift SPM package for full protocol support.

**AI Companion (FR-5):**
- `Core/AI/CompanionService.swift` — 6 DoctorPersona types (general, CBT, anxiety, trauma, stress, mood). On-device keyword fallback when backend offline. Backend LLM bridge via BackendService.
- `Features/Companion/CompanionView.swift` — chat UI, horizontal persona picker, typing indicator, persona sheet.

**DeviceActivity (FR-3):**
- `Core/DeviceActivity/DeviceActivityMonitor.swift` — anomaly detection logic (excessive social media, unusual hours, communication drop) fully implemented. Activation stubbed pending Apple FamilyControls entitlement approval.

**Onboarding (FR-6):**
- Expanded to 4 steps: Welcome → HealthKit → Emergency Contacts → Notifications → Calibration.
- ManasButtonStyle shared component extracted.

**App shell:**
- `RootView.swift` — TabView with Today/Companion/Settings tabs + CrisisView fullScreenCover.
- `ManasApp.swift` — all ObservableObjects wired; notification categories registered.
- `Features/Settings/SettingsView.swift` — emergency contacts CRUD, data export (no PHI), delete all data, privacy disclosure section, app version info.

**Info.plist:**
- NSCameraUsageDescription, NSMicrophoneUsageDescription added.
- UIAppFonts registered for all 5 Montserrat weights.

## 2026-06-03 — Infrastructure hardening + WebSocket migration

### Completed in this session (all committed)

**Telemetry transport — Socket.IO → Native WebSocket (ADR-003):**
- `BackendService.swift` rewritten to use `URLSessionWebSocketTask` with plain JSON
- Connects to `/ws/telemetry?token=<jwt>` — a new additive FastAPI endpoint
- All Socket.IO framing (Engine.IO handshake, `42[...]` event packets, namespace negotiation) removed
- Native WebSocket ping replaces manual Engine.IO PING frame
- React/MaanasWatch clients unaffected — Socket.IO server unchanged
- `docs/decisions/ADR-003-native-websocket.md` written with backend implementation snippet for Kinshuk

**AppConfig — multi-environment URL resolution:**
- `Core/Config/AppConfig.swift` — resolves API URL from `ManasDev.plist` → env var → compiled default
- Default: `http://localhost:8000` (dev); `NSAllowsLocalNetworking` added to Info.plist

**Certificate pinning:**
- SHA-256 public-key pinning implemented in `BackendService.URLSessionDelegate`
- Hash slot wired to `AppConfig.tlsPinnedHashes` — populated via `ManasDev.plist` or `MAANAS_PIN_HASH` env var
- Generates + compares hash of server leaf cert public key using `CryptoKit`

**FamilyControls entitlement:**
- `com.apple.developer.family-controls` added to `Manas.entitlements`
- `DeviceActivityMonitor` updated with activation code commented inline — one uncomment away once Apple approves
- Submission URL: apple.com/contact/request/family-controls-distribution

**Montserrat fonts:**
- All 5 weights (Regular/Medium/SemiBold/Bold/ExtraBold) downloaded from Google Fonts GitHub
- Bundled in `Manas/Resources/Fonts/`
- Registered in Info.plist `UIAppFonts`; added to Xcode project Resources build phase

**Facial emotion analysis (FR-2):**
- `Core/FacialEmotion/EmotionResult.swift` — 7-class `EmotionVector`, rolling `EmotionSession` smoother
- `Core/FacialEmotion/FACSRuleEngine.swift` — full Ekman AU→emotion rules from `VNFaceLandmarks2D` geometry (AU1/2/4/5/6/7/9/12/15/17/20/23/25/26)
- `Core/FacialEmotion/FacialEmotionAnalyzer.swift` — AVCaptureSession + Vision + CoreML two-tier pipeline; auto-stops on background; FACS-only mode when `.mlpackage` absent
- `BiometricSnapshot` updated with `emotionVector` field; `StressIndex.compute` updated to fuse physiological + facial signals
- `RiskScoringEngine` updated: emotion stress signal adds up to 15% weight when camera available

**CoreML model conversion (item 1 of 4 remaining):**
- `scripts/convert_emotion_model.py` — production converter for Kinshuk: ONNX → mlpackage targeting iOS 17, 7-class classifier contract, image normalization to [-1,1]
- `scripts/make_stub_model.py` — dev stub generator: minimal mlpackage returning near-neutral probabilities for end-to-end pipeline testing
- `scripts/README.md` — model contract, usage instructions, Xcode integration steps

**Documentation:**
- `docs/ui-mocks.html` v0.3 — HIG light mode, brand colors, Oura/Calm-inspired layout, actual logo
- `docs/wireframe-tree.html` — full app navigation tree with dark glass card styling
- `docs/architecture/ARCHITECTURE.md` — fully rewritten with transport split diagram, security table, nav structure, risk weight table

**Xcode project:**
- `project.pbxproj` updated: all 24 new Swift sources registered in Compile Sources; Resources build phase added (was missing); 5 fonts + 2 logos added to Copy Bundle Resources; 13 new groups added

## 2026-06-03 (continued) — Remaining open items sprint

### Item 1 — CoreML model conversion ✅
- `scripts/convert_emotion_model.py` — production ONNX→mlpackage converter for Kinshuk (Python 3.9-3.11 + coremltools)
- `scripts/make_stub_model.py` — dev stub that returns near-neutral probabilities for end-to-end pipeline testing
- `scripts/README.md` — model contract, usage, Xcode integration steps
- `FacialEmotionAnalyzer` already handles absent model gracefully (FACS-only fallback)

### Item 2 — FamilyControls Apple approval ✅
- `docs/compliance/FAMILY_CONTROLS_SUBMISSION.md` — complete prepared answers for Apple's request form: use case (individual self-monitoring), privacy practices, clinical justification, post-approval code steps
- `docs/decisions/ADR-004-device-activity.md` — records three anomaly categories, two-process extension architecture, post-approval work required
- Key architectural note: post-approval requires a separate `DeviceActivityReportExtension` Xcode target + App Group shared container

### Item 3 — Certificate pinning (intermediate CA) ✅
- Switched from leaf cert pinning to intermediate CA pinning in `BackendService.URLSessionDelegate`
- Chain walk: checks all certs in chain — pin survives leaf cert rotation (critical for Let's Encrypt 90-day renewals)
- `scripts/generate_pin_hash.sh` — fetches full chain via `openssl s_client -showcerts`, hashes each cert, labels which hash to use
- Dev mode: logs clearly when no pins configured; impossible to ship without noticing

## Open Items / Next Steps
- [ ] Run `scripts/make_stub_model.py` on Python 3.9-3.11 machine → add `EmotionClassifier.mlpackage` to Xcode target
- [ ] Kyle submits FamilyControls request to Apple (apple.com/contact/request/family-controls-distribution)
- [ ] Run `scripts/generate_pin_hash.sh api.maanas.health` once server is live → add hash to `ManasDev.plist`
- [ ] BAA with MAANAS backend operator before any PHI-adjacent data transmitted in production
- [ ] Kinshuk: add `@app.websocket("/ws/telemetry")` FastAPI endpoint (see ADR-003)
- [ ] Post FamilyControls approval: add DeviceActivityReportExtension Xcode target + App Group entitlement
