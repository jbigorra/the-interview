# Apply Services

Covers assisted application submission: routing to the correct ATS adapter, extracting form fields, and building application payloads from the user's profile data.

## Orchestrator

**Status:** ✅ Implemented

**Purpose:** Routes an application request to the correct ATS adapter based on the lead's `ats_type` attribute.

**Inputs:** `lead: [Lead]`, `profile: [Profile]`

**Success:** `{ success: true, response: { adapter: BaseAdapter, apply_url: String, fallback: Boolean } }`

**Failure:** `{ success: false, response: { error: { message: String }, apply_url: String } }` — includes `apply_url` on unsupported ATS so callers can fall back to manual apply.

---

## BaseAdapter

**Status:** ✅ Implemented

**Purpose:** Abstract base class for ATS-specific adapters. Provides `standard_fields` and `common_answers` helpers for mapping profile data to application fields.

**Methods:**
- `#extract_fields` — returns structured field definitions with pre-filled values
- `#build_payload` — builds the application payload from profile data
- `#apply_url` — returns the URL where the user should submit

---

## GreenhouseAdapter

**Status:** ✅ Implemented

**Purpose:** ATS adapter for Greenhouse job postings. Defines `STANDARD_FIELDS` array with id/label/type/required/value structure.

---

## LeverAdapter

**Status:** ✅ Implemented

**Purpose:** ATS adapter for Lever job postings. Uses `LEVER_FIELD_MAP` to map Lever's field names to standard profile fields. Combines first_name + last_name into a single "name" field.

---

## AshbyAdapter

**Status:** ✅ Implemented

**Purpose:** ATS adapter for Ashby job postings. Uses `ASHBY_FIELD_MAP` for camelCase field name mapping.
