# FamilyControls Entitlement — Apple Submission Guide

**Entitlement:** `com.apple.developer.family-controls`  
**Apply at:** https://developer.apple.com/contact/request/family-controls-distribution  
**Submitted by:** Kyle Downey (VP Engineering, MANAS)  
**App Bundle ID:** `com.manas.app`

---

## Prepared Answers for Apple's Request Form

### 1. App Name and Description

**App name:** Manas

**Description:**
Manas is an AI-powered mental health companion app that passively monitors
an individual's wellbeing signals — heart rate variability, sleep quality,
activity patterns, and app usage behavior — to detect early signs of mental
health deterioration before a crisis occurs. It is designed for individual
adults who want proactive, private, always-on mental health support.

---

### 2. How will you use the Screen Time / DeviceActivity APIs?

Manas uses `DeviceActivity` exclusively for **individual self-monitoring** —
not parental controls or family monitoring of any kind. The specific use
cases are:

**Behavioral anomaly detection as a mental health signal:**
- Sudden drop in communication app usage (e.g. texting/calling drops to
  <30% of a user's personal 7-day baseline) — a clinically recognized
  early indicator of social withdrawal and depression
- Excessive social media use (>2× personal baseline) — associated with
  anxiety and mood deterioration
- Unusual usage hours (activity between midnight–5am) — disrupted sleep
  patterns are a key risk marker

**What Manas does NOT do:**
- Does not restrict or block any apps
- Does not report usage to parents, guardians, or third parties
- Does not monitor children (users must be 18+)
- Does not transmit raw app usage data off-device

**Data handling:**
All `DeviceActivityReport` processing occurs on-device within the app
extension sandbox. Only a boolean anomaly flag and category label (e.g.
`communication_drop`) are passed to the main app. Raw usage data (app
names, durations) never leave the device. The anomaly flag is fused with
biometric signals (heart rate, HRV, sleep) in the on-device risk engine.

**Authorization mode:**
The app calls `AuthorizationCenter.shared.requestAuthorization(for: .individual)` —
the individual (self) authorization mode, not `.family`. Users explicitly
consent during onboarding and can revoke access at any time in Settings.

---

### 3. Who are your users?

- **Age:** Adults 18 and older only
- **Relationship:** The user monitors their own device activity — no
  parent/child relationship involved
- **Authorization type:** `.individual` (self-monitoring only)
- **Consent:** Explicit in-app consent step during onboarding with clear
  explanation of what is monitored and how it is used

---

### 4. Privacy practices

| Practice | MANAS implementation |
|----------|----------------------|
| Data minimization | Only boolean anomaly flags leave DeviceActivityReport; no raw app names or durations |
| On-device processing | All DeviceActivity analysis runs in the app extension sandbox |
| User control | User can revoke DeviceActivity access at any time via Settings → Manas → Screen Time |
| No third-party sharing | Usage data is never sent to any server or analytics SDK |
| HIPAA-aligned | App is developed under HIPAA-aligned data handling practices (academic pilot scope) |
| Transparency | In-app Settings screen shows all active monitoring signals and their purpose |

---

### 5. Business and clinical justification

Mental health crises rarely emerge suddenly — they follow a trajectory of
behavioral changes that are detectable weeks or months in advance. Changes
in social communication patterns and sleep-adjacent phone use are among
the most reliable early warning signals identified in clinical research
(PHQ-9, GAD-7 correlates).

MANAS fuses app usage anomaly data (from DeviceActivity) with biometric
signals (HealthKit) to produce a unified, personalized risk score. This
multimodal approach is clinically grounded in the MAANAS AI engine
developed by the team (hybrid FACS + ONNX + rPPG architecture).

The goal is to reduce the average time between symptom onset and
intervention from years (current average) to days — specifically for
underserved populations who lack access to traditional mental health care.

---

### 6. Supporting information

- **Developer Team:** MANAS — MIT CTO Program, Cohort Group 2
- **Contact:** downey.kyle@gmail.com (VP Engineering)
- **App type:** Health & Fitness / Mental Health
- **Deployment:** Academic pilot (P2 deliverable); 500+ users across
  3 pilot sites (university campus, veterans healthcare, community)
- **SDK:** DeviceActivity + FamilyControls (iOS 17+); `.individual` mode only

---

## Post-Approval Code Steps

Once Apple approves the entitlement, the following changes are needed:

### 1. Uncomment activation code in `DeviceActivityMonitor.swift`

In `requestAuthorization()`:
```swift
import FamilyControls

try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
isAuthorized = true
```

In `startMonitoring()`:
```swift
import DeviceActivity

let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd:   DateComponents(hour: 23, minute: 59),
    repeats: true
)
let center = DeviceActivityCenter()
try? center.startMonitoring(.daily, during: schedule)
```

### 2. Add DeviceActivityReport Extension target in Xcode

DeviceActivity data is delivered to a **separate app extension** (not the
main app directly). Add a new target:

- File → New → Target → Device Activity Report Extension
- Bundle ID: `com.manas.app.activity-report`
- Enable FamilyControls in the extension's entitlements too
- Implement `DeviceActivityReportExtension` to aggregate usage and pass
  anomaly categories to the main app via App Group shared container

### 3. Add App Group entitlement

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.manas.app</string>
</array>
```

Add to both the main app and the extension entitlements. Use
`UserDefaults(suiteName: "group.com.manas.app")` to share anomaly data
from the extension to the main app.

### 4. Update onboarding

The `NotificationsStep` in `OnboardingView.swift` should add a
DeviceActivity permission step once the entitlement is active.
