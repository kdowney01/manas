# MANAS iOS App — Claude Context

## What This Project Is

MANAS (Multimodal AI for Awareness, Neurocognitive Analysis & Support) is an iOS app that passively monitors users for early signs of mental health deterioration using biometrics, facial emotion, and behavioral signals. It is the mobile-first pilot deliverable (P2) of the MIT CTO Program Impact Project.

See `docs/PROJECT_OVERVIEW.md` for full context.

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI
- **AI (on-device):** CoreML (converted from ONNX)
- **AI (backend):** MAANAS FastAPI engine (Python, ONNX + FACS + rPPG)
- **Key Frameworks:** HealthKit, AVFoundation, Vision, CoreML, DeviceActivity, FamilyControls
- **Min iOS:** 17.0

## Key Docs

- `docs/PROJECT_OVERVIEW.md` — vision, team, impact targets
- `docs/architecture/ARCHITECTURE.md` — system design
- `docs/requirements/REQUIREMENTS.md` — functional and non-functional requirements
- `docs/decisions/` — Architecture Decision Records
- `docs/history/PROJECT_HISTORY.md` — project timeline

## Critical Constraints

1. **No raw biometric data ever leaves the device without explicit user consent**
2. **No raw facial video stored or transmitted at any time**
3. **App must function fully offline** (on-device CoreML fallback)
4. **DeviceActivity / FamilyControls entitlements** require Apple developer provisioning
5. **iOS 17+ required** for latest DeviceActivity APIs
6. **HealthKit background delivery** must be enabled in entitlements

## MIT Course Alignment

This project must conform to MIT Professional Education CTO Program standards. Architecture decisions should be defensible using technology roadmapping (MOT) frameworks. Portfolio decomposition: this app = P2 deliverable.
