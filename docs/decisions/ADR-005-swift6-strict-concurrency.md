# ADR-005: Swift 6 Language Mode with Strict Concurrency

**Date:** 2026-06-14
**Status:** Accepted — build green (0 errors, 0 warnings) under Swift 6

## Context

The project's `project.yml` sets `SWIFT_VERSION: "6.0"`, which compiles the app
in **Swift 6 language mode** with strict, compile-time data-race checking. The
codebase, however, was originally written in a Swift-5 idiom (singletons via
`static let shared`, `@MainActor` classes that also act as `URLSession` /
`UNUserNotificationCenter` delegates, an `AVCapture` pipeline) and had never been
compiled under Swift 6. The first full build surfaced a cluster of strict-concurrency
errors in four files.

A short-lived expedient — dropping to `SWIFT_VERSION: "5.0"` — was considered and
briefly applied to unblock the build. It was reverted: for a health- and
safety-adjacent app full of concurrent boundaries (HealthKit callbacks, camera
capture queue, notification/URLSession delegates, background tasks), the
compile-time data-race guarantees of Swift 6 are worth keeping. Strict mode also
caught a **genuine bug**: `FacialEmotionAnalyzer` was invoking a `@MainActor`
method directly from the background capture-delegate queue.

## Decision

Stay in **Swift 6 language mode** and resolve each concurrency issue at the source
rather than relaxing the checker.

| File | Issue | Fix |
|------|-------|-----|
| `SecureStorage.swift` | `static let shared` of a non-`Sendable` class | Conform the stateless Keychain wrapper to `Sendable` (no mutable instance state) |
| `AlertManager.swift` | `UNUserNotificationCenterDelegate` methods crossed into `@MainActor`, receiving non-`Sendable` UN* types | Mark the two delegate methods `nonisolated` (they touch no main-actor state) |
| `BackendService.swift` | `URLSessionDelegate` cert-pinning conformance crossed into `@MainActor` | Mark the delegate method `nonisolated`; expose the immutable `config` as `nonisolated let` (AppConfig is an implicitly-`Sendable` struct) |
| `FacialEmotionAnalyzer.swift` | Capture delegate (background queue) called the `@MainActor` Vision/CoreML pipeline | Make the pipeline (`analyze`/`handleLandmarks`/`handleCoreMLResult`/`computeReliability`) `nonisolated`; confine its mutable state to the serial vision queue via `nonisolated(unsafe)`; hop to `@MainActor` only to publish `@Published` results |

The two unrelated language errors uncovered alongside these (the `Environment` enum
shadowing SwiftUI's `@Environment`, and the brand-color tokens not resolving in
leading-dot `ShapeStyle` position) were fixed independently — see the git history
for `AppConfig.swift` and `BrandColors.swift`.

## Consequences

- **Off-main inference preserved.** The facial-emotion pipeline keeps running on the
  background `visionQueue`; only derived `EmotionVector` results hop to the main actor.
  This is both the correct architecture and a fix for the wrong-thread access strict
  mode exposed.
- **`nonisolated(unsafe)` is used deliberately and narrowly.** It appears only where
  state is provably confined to a single serial queue (the vision pipeline's
  `frameCount`, `coreMLModel`, `facsEngine`, `lastReliability`, and the one-shot
  `AVCaptureSession` hand-off). Each use carries a comment justifying the safety
  invariant. If any of these stops being single-queue-confined, the annotation must
  be revisited.
- **New code is held to the same bar.** Phase 2+ of the prototype port (digital
  signals provider, stores, view models) should compile clean under Swift 6 without
  `@unchecked`/`unsafe` escape hatches except where a documented invariant warrants it.

## Alternatives considered

- **Swift 5 language mode** (`SWIFT_VERSION: "5.0"`): one-line, reversible, and matches
  the codebase's original idiom — but silently forfeits data-race safety for a
  safety-adjacent app and would let real races (like the camera one) ship unflagged.
  Rejected as the long-term mode; acceptable only as a temporary unblock.
- **`@preconcurrency` on the delegate conformances**: suppresses the diagnostics by
  deferring data-race checks to runtime traps. Rejected in favor of `nonisolated`,
  which states the actual isolation correctly.
