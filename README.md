# MANAS

**MANAS** (Multimodal AI for Awareness, Neurocognitive Analysis & Support) is an
AI-driven, always-on mental health companion for iOS that proactively detects the
risk of a mental health crisis **before** it occurs — without requiring the user to
recognize or report their own distress.

It is the **P2 deliverable** (MVP platform + pilot app) of the MIT Professional
Education CTO Program (Cohort Group 2) Impact Project, developed as a real product.

---

## The Problem

- 1 in 8 people globally live with a mental health condition.
- 50% of conditions begin by age 14, 75% by age 24 — yet detection is delayed by years.
- Existing apps are **reactive**: they wait for the user to recognize and report distress.
- 80% of mental health app users quit within 30 days.
- Only ~1 mental health professional exists per 100,000 people globally.

## The Approach

Manas listens **passively and continuously** across multiple signal streams to detect
early warning signs of a negative mental-health trajectory and intervene before a crisis
escalates:

- **Biometrics** — heart rate, HRV, resting HR, sleep, and activity via HealthKit
- **Facial emotion** — on-device FACS / Ekman analysis (Vision + CoreML), no video stored
- **Digital behavior** — social media usage, message & email *tone*, and screen time
  (derived signals only — never raw content)

A weighted **Risk Scoring Engine** establishes a personal 7-day baseline, then flags
meaningful deviations and escalates through gentle nudges → high-risk check-ins →
crisis support (988, emergency contacts, AI companion).

### Design principles

1. **Early detection** — surface risk 6–12 months sooner than current clinical pathways
2. **Always-on** — passive monitoring, no burden on the user
3. **Privacy first** — on-device inference; raw biometric/facial/content data never leaves the device
4. **Inclusive** — designed to work across cultures, languages, and underserved populations

---

## Repository Layout

| Path | Description |
|------|-------------|
| `Manas/` | Swift / SwiftUI iOS app source (iOS 17+) |
| `Manas.xcodeproj` / `project.yml` | Xcode project (XcodeGen-managed) |
| `HTML_Prototype/` | Standalone interactive HTML prototype (see below) |
| `docs/` | Architecture, requirements, ADRs, compliance, history, UI mocks |
| `scripts/` | ONNX→CoreML conversion, cert-pin hash generation, dev stubs |
| `CLAUDE.md` | Engineering context for AI-assisted development |
| `ACTIONS.md` | Outstanding team follow-up actions |

### iOS app — what's built

- **Core / Security** — Keychain storage (AES-256, file protection), local notifications, emergency-contact store
- **HealthKit & Risk** — biometric ingestion with background delivery; weighted risk scoring with 7-day calibration
- **Facial emotion** — AVFoundation + Vision + CoreML pipeline with a FACS rule-engine fallback
- **Backend & AI** — JWT-authenticated REST + native WebSocket bridge (derived scores only); 6-persona AI companion with an on-device keyword fallback
- **Features** — Onboarding, Dashboard, Companion, Crisis, Settings

### Documentation

- [Project Overview](docs/PROJECT_OVERVIEW.md) — vision, problem, team, target impact, R&D portfolio
- [Architecture](docs/architecture/ARCHITECTURE.md) — system design
- [Requirements](docs/requirements/REQUIREMENTS.md) — functional & non-functional requirements
- [Project History](docs/history/PROJECT_HISTORY.md) — timeline
- **Architecture Decision Records**
  - [ADR-001 — Swift / SwiftUI](docs/decisions/ADR-001-swift-swiftui.md)
  - [ADR-002 — On-device-first inference](docs/decisions/ADR-002-on-device-first-inference.md)
  - [ADR-003 — Native WebSocket](docs/decisions/ADR-003-native-websocket.md)
  - [ADR-004 — DeviceActivity](docs/decisions/ADR-004-device-activity.md)
- **Compliance**
  - [BAA Requirements](docs/compliance/BAA_REQUIREMENTS.md)
  - [FamilyControls Submission](docs/compliance/FAMILY_CONTROLS_SUBMISSION.md)
- **UI** — [UI mocks](docs/ui-mocks.html) · [wireframe tree](docs/wireframe-tree.html) (open in a browser)

---

## HTML Prototype

`HTML_Prototype/` is a **self-contained, dependency-free** interactive prototype of the
iOS app, used to demo and iterate on flows and UX quickly — before committing them to the
Swift codebase. It runs in any modern browser straight from the filesystem.

### Run it

```bash
open HTML_Prototype/index.html        # macOS
```

No build step, no server, no install. It works over the `file://` protocol. On desktop it
renders inside an iPhone frame with a **Dev Tools** panel; on narrow screens it goes
full-bleed (the dev panel and phone chrome hide automatically).

### Structure

```
HTML_Prototype/
├── index.html      # iPhone frame, tab bar, dev-tools panel, modal host
├── css/styles.css  # Design tokens + all component & screen styles
├── js/app.js       # Single-file SPA: state, router, screens, events
└── assets/         # Logo and image assets
```

State is held in a single `state` object and persisted to `localStorage`
(`manas_proto_state`), so onboarding progress and choices survive a refresh.

### Screens & flows

- **Onboarding (6 steps):** Welcome → Health Access → **Digital Wellbeing** →
  Emergency Contacts → Notifications → Calibration
- **Dashboard:** wellbeing-score ring, biometric tiles, **Digital Wellbeing** signals,
  daily insight, and recent alerts
- **Companion:** chat UI with 6 doctor personas and a simulated, keyword-driven responder
- **Crisis:** 988 call/text, emergency-contact alerts, companion link
- **Settings:** emergency contacts, notifications, digital-signals toggle, privacy, data export/delete

### Digital signals (onboarding + dashboard)

The prototype models **social media usage, message tone, email tone, and screen time**
as wellbeing inputs:

- A dedicated **"Digital Wellbeing"** onboarding step with per-signal toggles and a
  **Skip for now** option.
- A **"Digital Wellbeing"** dashboard section showing tiles for the enabled signals, or a
  *"Add digital signals"* prompt (with an enable sheet) when the user skipped.
- Privacy framing throughout: only **derived** scores (tone, frequency, duration) are
  computed, **on-device** — raw messages, emails, and content are never stored or transmitted.

### Dev Tools

The desktop dev panel (right of the phone) lets you:

- Jump directly to any screen
- Force a risk level (Low / Moderate / High / Crisis)
- Refresh mock biometrics and reset onboarding
- Watch live app state (current screen, risk, wellness, contacts, persona, onboarding, digital on/off)

---

## Privacy & Compliance

MANAS is built to a **HIPAA-aware** standard. Non-negotiable constraints:

1. No raw biometric values in logs, notifications, or backend payloads — derived scores only.
2. No raw facial video stored or transmitted at any time.
3. No raw message or email content stored or transmitted — only on-device derived signals.
4. All sensitive storage in the Keychain — never `UserDefaults`.
5. The app must function fully **offline** via on-device fallbacks.
6. A **BAA** is required before any PHI-adjacent data is transmitted to the backend.
7. `DeviceActivity` / `FamilyControls` features require Apple entitlement approval.

See `docs/compliance/` for BAA requirements and the FamilyControls submission materials.

---

## Tech Stack

- **Language / UI:** Swift 5.9+, SwiftUI (HIG light-mode, Montserrat)
- **On-device AI:** CoreML (converted from ONNX), Vision, AVFoundation
- **Backend AI:** MAANAS FastAPI engine (Python — ONNX + FACS + rPPG)
- **Key frameworks:** HealthKit, UserNotifications, MessageUI, DeviceActivity, FamilyControls
- **Minimum iOS:** 17.0

## Team

| Name |
|------|
| Daniel Gumucio |
| Sunita Gogineni |
| Blair Day |
| Kyle Downey |
| Kinshuk Dutta |

---

*MIT Professional Education CTO Program — Cohort Group 2 — Impact Project (P2).*
