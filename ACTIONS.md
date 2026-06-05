# MANAS — Required Follow-Up Actions

Actions Kyle or the team must take outside of code. Ordered by priority.

---

## 🔴 Blocking (required before any production / pilot use)

### 1. Execute BAA with MAANAS Backend Operator
**Owner:** Daniel Gumucio (CEO) + Kyle  
**What:** Sign a Business Associate Agreement with the MAANAS backend operator before any PHI-adjacent data (telemetry, chat, risk events) is transmitted.  
**Reference:** `docs/compliance/BAA_REQUIREMENTS.md`  
**After signing:** Add to `ManasDev.plist`:
```xml
<key>MAANAS_BAA_CONFIRMED</key>
<true/>
```

### 2. Confirm IBM Watsonx BAA Coverage
**Owner:** Kinshuk Dutta  
**What:** Verify the existing Watsonx contract includes a HIPAA BAA. If not, LLM chat must redact all biometric context until one is in place.  
**Reference:** `docs/compliance/BAA_REQUIREMENTS.md` — Vendor 2

---

## 🟡 Required before full feature set works

### 3. Submit FamilyControls Entitlement Request to Apple
**Owner:** Kyle  
**What:** Submit the entitlement request at:  
https://developer.apple.com/contact/request/family-controls-distribution  
**Prepared answers:** `docs/compliance/FAMILY_CONTROLS_SUBMISSION.md` — copy/paste ready  
**Turnaround:** Typically 1–3 business days  
**After approval:**
- Uncomment activation code in `Manas/Core/DeviceActivity/DeviceActivityMonitor.swift` (paths marked inline)
- Add `DeviceActivityReportExtension` Xcode target
- Add `group.com.manas.app` App Group entitlement to both targets
- Wire shared `UserDefaults` container between extension and main app

### 4. Add Montserrat Fonts to Xcode Target
**Owner:** Kyle  
**What:** The `.ttf` files are in `Manas/Resources/Fonts/` but need to be added to the Xcode target's Copy Bundle Resources phase.  
**Steps:**
1. Open `Manas.xcodeproj` in Xcode
2. Select the Manas target → Build Phases → Copy Bundle Resources
3. Click `+` → add all 5 files from `Manas/Resources/Fonts/`
4. Build and verify `Font.custom("Montserrat-Bold", ...)` resolves correctly

### 5. Generate and Configure TLS Cert Pin Hash
**Owner:** Kyle / Kinshuk (once production server is live)  
**What:** Run the hash generation script against the production server and add the intermediate CA hash to config.  
**Command:**
```bash
./scripts/generate_pin_hash.sh api.maanas.health
```
**Then add to `ManasDev.plist`:**
```xml
<key>MAANAS_PIN_HASH</key>
<string>PASTE_INTERMEDIATE_HASH_HERE</string>
```

---

## 🟢 Required before pilot testing

### 6. Generate Dev EmotionClassifier.mlpackage (Stub)
**Owner:** Kyle or Kinshuk (needs Python 3.9–3.11)  
**What:** Run the stub model generator so `FacialEmotionAnalyzer` can test the full camera→Vision→CoreML pipeline locally.  
**Command:**
```bash
cd scripts
pip install coremltools numpy
python3 make_stub_model.py --output ../Manas/Resources/EmotionClassifier.mlpackage
```
**Then:** Add `EmotionClassifier.mlpackage` to the Xcode target (File → Add Files to "Manas").

### 7. Convert Real Emotion Model (Production)
**Owner:** Kinshuk Dutta  
**What:** Convert `emotion_model.onnx` from the MAANAS engine to `EmotionClassifier.mlpackage` for on-device CoreML inference.  
**Command (on macOS, Python 3.9–3.11):**
```bash
cd scripts
pip install coremltools onnx onnxruntime
python3 convert_emotion_model.py \
    --input  /path/to/maanas/models/emotion_model.onnx \
    --output /path/to/manas/Manas/Resources/EmotionClassifier.mlpackage
```
**Reference:** `scripts/README.md`

### 8. Add Backend WebSocket Endpoint
**Owner:** Kinshuk Dutta  
**What:** Add a native WebSocket endpoint to the MAANAS FastAPI backend for iOS telemetry.  
**Reference:** `docs/decisions/ADR-003-native-websocket.md` — includes the full implementation (~15 lines of Python).  
**Endpoint:** `@app.websocket("/ws/telemetry")` with JWT query-param auth  
**Note:** The existing Socket.IO server is unchanged — this is additive.

---

## 📋 Ongoing / Administrative

### 9. Annual BAA Review
**Owner:** Daniel Gumucio  
**What:** Review all executed BAAs annually and update the execution log in `docs/compliance/BAA_REQUIREMENTS.md`.

### 10. Cert Hash Rotation
**Owner:** Kyle / DevOps  
**What:** When the production server's CA changes (e.g. switching from Let's Encrypt to a paid cert), regenerate the pin hash and update `ManasDev.plist`. Run `scripts/generate_pin_hash.sh` again.

### 11. FamilyControls Annual Re-authorization
**Owner:** Kyle  
**What:** Apple may require re-submission if the app's use of Screen Time APIs changes materially. Review annually.

---

## Summary Table

| # | Action | Owner | Blocking? | Status |
|---|--------|-------|-----------|--------|
| 1 | Execute BAA with backend operator | Daniel / Kyle | 🔴 Yes | ⏳ Pending |
| 2 | Confirm Watsonx BAA | Kinshuk | 🔴 Yes | ⏳ Pending |
| 3 | Submit FamilyControls to Apple | Kyle | 🟡 Feature | ⏳ Pending |
| 4 | Add Montserrat to Xcode target | Kyle | 🟡 Feature | ⏳ Pending |
| 5 | Generate TLS cert pin hash | Kyle / Kinshuk | 🟡 Production | ⏳ Needs server |
| 6 | Generate stub mlpackage | Kyle / Kinshuk | 🟢 Pilot | ⏳ Pending |
| 7 | Convert real emotion model | Kinshuk | 🟢 Pilot | ⏳ Pending |
| 8 | Add /ws/telemetry to backend | Kinshuk | 🟢 Pilot | ⏳ Pending |
| 9 | Annual BAA review | Daniel | 📋 Ongoing | — |
| 10 | Cert hash rotation | Kyle | 📋 Ongoing | — |
| 11 | FamilyControls re-auth review | Kyle | 📋 Ongoing | — |
