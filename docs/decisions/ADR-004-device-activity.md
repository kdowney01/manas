# ADR-004: DeviceActivity for Behavioral Anomaly Detection

**Date:** 2026-06-03  
**Status:** Accepted — implementation complete, entitlement pending Apple approval

## Context

Mental health deterioration is often preceded by measurable behavioral
changes: social withdrawal, disrupted sleep patterns, excessive social
media use. These signals are detectable through app usage patterns on
the user's iPhone.

Apple's DeviceActivity framework (part of the Screen Time API) provides
access to per-app usage data. It requires the `com.apple.developer.family-controls`
entitlement, which Apple must explicitly approve.

## Decision

Use DeviceActivity in **individual self-monitoring mode** (`.individual`
authorization) to detect three behavioral anomaly categories:

| Category | Signal | Threshold |
|----------|--------|-----------|
| `communication_drop` | Communication app usage < 30% of personal 7-day baseline | Social withdrawal marker |
| `excessive_social_media` | Social media use > 2× personal baseline | Anxiety/mood correlation |
| `unusual_hours` | Active usage between midnight–5am | Sleep disruption proxy |

The anomaly flag feeds into `RiskScoringEngine` alongside HRV, heart rate,
sleep, and facial emotion signals.

## Architecture

Due to Apple's sandboxing model, DeviceActivity data is delivered to a
**separate app extension target** (`DeviceActivityReportExtension`), not
the main app directly. The extension aggregates usage, computes anomaly
flags, and writes them to an App Group shared container
(`group.com.manas.app`). The main app reads from the shared container.

```
DeviceActivityCenter (main app)
    → monitors schedule
    → triggers DeviceActivityReportExtension
        → receives raw usage data (sandboxed)
        → computes: detected: Bool, categories: [Category]
        → writes to UserDefaults(suiteName: "group.com.manas.app")
    ← main app reads anomaly flag
    → DeviceActivityMonitor.evaluateUsage(...)
    → RiskScoringEngine
```

## Privacy Rationale

- Only boolean anomaly flags cross the extension boundary — no app names
  or raw usage durations ever reach the main app or any server
- Authorization is `.individual` (self-monitoring only, never parental)
- User can revoke access at any time via iOS Settings
- Anomaly detection uses personal baselines, not population thresholds —
  avoiding false positives for users with atypical but stable patterns

## Entitlement Status

- Code: ✅ complete (`DeviceActivityMonitor.swift`, activation commented inline)
- Entitlement key: ✅ in `Manas.entitlements`
- Apple approval: ⏳ pending — apply at apple.com/contact/request/family-controls-distribution
- Submission materials: `docs/compliance/FAMILY_CONTROLS_SUBMISSION.md`

## Post-Approval Work Required

1. Uncomment activation code in `DeviceActivityMonitor.swift`
2. Add `DeviceActivityReport` Extension target in Xcode
3. Add `group.com.manas.app` App Group entitlement to both targets
4. Implement extension to aggregate and share anomaly flags
5. Add DeviceActivity consent step to onboarding

## Tradeoffs

- **Requires Apple approval:** Unlike HealthKit, this entitlement is not
  self-service. Typical approval takes 1–3 business days for wellness apps.
- **Extension architecture:** The two-process model adds complexity vs.
  a direct API, but is a deliberate Apple privacy boundary — it prevents
  main app code from seeing raw usage data.
- **Behavioral signal only:** DeviceActivity provides no biometric ground
  truth — it is one signal among several, weighted accordingly in the
  risk engine.
