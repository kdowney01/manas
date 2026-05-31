# MANAS iOS App — Requirements

## Functional Requirements

### FR-1: Passive Biometric Monitoring
- Continuously read heart rate and HRV from HealthKit (background delivery)
- Analyze rPPG from front camera when app is in foreground
- Monitor sleep quality and activity level via HealthKit

### FR-2: Facial Emotion Analysis
- Detect facial landmarks using Vision framework (VNFaceObservationRequest)
- Classify 7 basic emotions: neutral, happy, sad, angry, fearful, disgusted, surprised
- Apply FACS Action Unit rules for symbolic validation
- Send frames to MAANAS backend for full ONNX+FACS+WLOP inference when connected

### FR-3: App Usage Monitoring
- Use DeviceActivity framework to detect anomalous usage patterns
- Flag: excessive social media use, unusual hours, sudden drops in communication apps
- All aggregation happens on-device; only anomaly flag (boolean + category) is reported

### FR-4: Risk Scoring & Alerting
- Fuse biometric, facial, and behavioral signals into a unified risk score
- Maintain personalized user baseline for each signal (avoids false positives)
- Risk levels: `.low`, `.moderate`, `.high`, `.crisis`
- At `.high`: gentle in-app nudge + optional AI companion conversation
- At `.crisis`: immediate escalation workflow (emergency contact + optional 988 prompt)

### FR-5: AI Companion
- Connect to MAANAS LLM backend (IBM Watsonx / Llama 3.1)
- Inject real-time biometric context into companion prompts
- Support 6 specialized doctor personas (CBT, anxiety, trauma, stress, mood, general)
- Fallback to on-device keyword-based responses if backend unavailable

### FR-6: User Onboarding & Consent
- Explicit consent for every data source (HealthKit, camera, microphone, DeviceActivity)
- Baseline calibration period (7 days) before risk scoring activates
- Users can view, export, or delete all their data at any time

### FR-7: Emergency Contact Routing
- User configures 1–3 emergency contacts during onboarding
- At crisis threshold: notify contacts via system push notification
- Include optional direct link to 988 Suicide & Crisis Lifeline

## Non-Functional Requirements

### NFR-1: Privacy
- Zero raw biometric data transmitted — only derived scores
- No raw video stored or transmitted at any time
- All HealthKit data remains on-device unless user explicitly shares
- HIPAA-aligned data handling (academic prototype scope)

### NFR-2: Performance
- Background biometric monitoring: <2% battery impact per hour
- Foreground risk score update: <500ms latency
- On-device ML inference: <100ms per frame (CoreML)

### NFR-3: Reliability
- App functions fully offline (degraded mode: on-device models only)
- No data loss if backend is unreachable (local queue with retry)

### NFR-4: Platform
- iOS 17.0 minimum (DeviceActivity + latest HealthKit APIs)
- Swift 5.9 / Xcode 15+
- iPhone only for v1 (iPad deferred)
- WatchOS companion app: v2 (leverages existing MaanasWatch codebase)

### NFR-5: MIT Course Compliance
- Architecture must demonstrate technology roadmapping principles (MOT course)
- R&D portfolio alignment: this app = P2 deliverable
- Must support pilot methodology with measurable KPIs (P5)

## Out of Scope (v1)

- iPad support
- Android
- Clinical certification / FDA clearance
- Real-time video streaming to backend (privacy risk; deferred to v2 with explicit opt-in)
- Social graph analysis
