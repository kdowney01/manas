# MANAS — Business Associate Agreement (BAA) Requirements

## What Is a BAA and Why MANAS Needs One

Under HIPAA, a Business Associate Agreement is required whenever a Covered
Entity (or Business Associate) shares Protected Health Information (PHI)
with a third-party vendor that processes that data on their behalf.

MANAS is designed as a HIPAA-aligned platform. Even though it is currently
an academic pilot, it handles health-adjacent data (biometric signals, risk
scores, mental health context) that could constitute PHI when linked to an
identifiable individual. A BAA must be in place with every backend vendor
before any such data is transmitted.

---

## Vendors That Require a BAA

### 1. MAANAS Backend Operator (Priority — blocks production)

**What data is transmitted:**
- JWT-authenticated telemetry: `stressIndex` (derived from HR + HRV + emotion)
- Risk event severity labels (`.high`, `.crisis`) + timestamps
- LLM chat messages that may contain user-disclosed health context
- User ID (linked to identity in the backend database)

**Why it triggers BAA:** The combination of a user identifier + health-derived
signals constitutes PHI under HIPAA. The backend operator stores and
processes this data on MANAS's behalf.

**Action:** Execute a BAA with Daniel Gumucio / the MAANAS backend operator
before enabling telemetry and LLM chat in production.

**Runtime gate:** `BackendService.baaConfirmed` must be set to `true` before
telemetry and chat calls proceed. See `AppConfig` and `BackendService`.

---

### 2. IBM Watsonx / LLM Proxy Vendor (If used in production)

**What data is transmitted:** LLM chat messages with injected biometric
context (risk level, stress index).

**Why it triggers BAA:** Chat messages may contain user-disclosed mental
health information. The LLM processes this on MANAS's behalf.

**Action:** IBM offers a HIPAA BAA for Watsonx enterprise customers.
Confirm with Kinshuk whether the existing Watsonx contract includes a BAA.
If not, the LLM proxy must redact all biometric context before forwarding
to Watsonx until a BAA is in place.

---

### 3. Crash Reporting / Analytics (If added)

Do NOT add any crash reporting or analytics SDK (Firebase, Sentry, Mixpanel,
etc.) without first confirming a BAA is available and executed. These SDKs
often capture device state that could include PHI-adjacent data.

**Current status:** No analytics SDK in the app. Keep it this way until
BAAs are in place.

---

## What the BAA Must Cover

Any BAA with the MAANAS backend operator must include:

| Requirement | Detail |
|-------------|--------|
| Permitted uses | Backend may process data only for MANAS service delivery |
| Safeguards | Encryption at rest (AES-256) and in transit (TLS 1.2+) required |
| Breach notification | Vendor must notify MANAS within 60 days of discovery |
| Subcontractors | Vendor must execute BAAs with any subprocessors (e.g. cloud provider) |
| Data return/destruction | On termination, vendor must return or destroy all PHI |
| Audit rights | MANAS may audit vendor's HIPAA compliance on reasonable notice |
| Minimum necessary | Vendor may access only the minimum data needed for the service |

---

## Runtime Enforcement

`BackendService` includes a `baaConfirmed` flag that must be set to `true`
before telemetry and LLM chat calls are permitted. This is controlled by
`AppConfig.baaConfirmed`, which reads from:

1. `ManasDev.plist` key `MAANAS_BAA_CONFIRMED = true`
2. Environment variable `MAANAS_BAA_CONFIRMED`
3. Default: `false` (blocks all PHI-adjacent calls)

When `baaConfirmed = false`, `BackendService` still allows:
- `POST /api/auth/login` (no PHI, just credentials)

But blocks:
- WebSocket telemetry
- `POST /api/llm/chat`
- `POST /api/risk/event`

---

## Checklist

- [ ] Identify legal signatory for MANAS (Daniel Gumucio / CEO)
- [ ] Request BAA from MAANAS backend operator
- [ ] Review BAA against requirements table above
- [ ] Execute (sign) the BAA
- [ ] Set `MAANAS_BAA_CONFIRMED = true` in production `AppConfig`
- [ ] Confirm IBM Watsonx contract includes BAA coverage
- [ ] Document BAA execution date in this file
- [ ] Schedule annual BAA review

---

## BAA Execution Log

| Vendor | Status | Date | Signatory |
|--------|--------|------|-----------|
| MAANAS backend | ⏳ Pending | — | — |
| IBM Watsonx | ⏳ To confirm | — | — |
