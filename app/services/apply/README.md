# Apply Services

Covers assisted application submission: routing to the correct ATS adapter and building/submitting application payloads.

## Orchestrator

**Purpose:** Routes an application request to the correct ATS adapter based on the lead's `ats_type` attribute.

**Inputs:** `lead: [Lead]`, `profile: [Profile]`

**Success:** `{ success: true, response: { adapter: BaseAdapter, apply_url: String } }`

**Failure:** `{ success: false, response: { error: { message: String }, apply_url: String } }` — includes `apply_url` on unsupported ATS so callers can fall back to manual apply.

**Raises:** `StandardError` (internally rescued).

---

## BaseAdapter

**Purpose:** Abstract base class for ATS-specific adapters. Not called directly — use concrete subclasses.

**Methods:** `#extract_fields`, `#build_payload`, `#apply_url` — all raise `NotImplementedError` in the base.

---

## GreenhouseAdapter

**Purpose:** ATS adapter for Greenhouse job postings. **Stub — field extraction/payload building not yet implemented.**

**Inputs:** `lead: [Lead]`, `profile: [Profile]` (via `BaseAdapter#initialize`)

**Success (when implemented):** `{ success: true, response: { payload: Hash } }`

**Failure:** `{ success: false, response: { error: { message: String } } }`

---

## LeverAdapter

**Purpose:** ATS adapter for Lever job postings. **Stub — not yet implemented.**

Same contract as GreenhouseAdapter.

---

## AshbyAdapter

**Purpose:** ATS adapter for Ashby job postings. **Stub — not yet implemented.**

Same contract as GreenhouseAdapter.
