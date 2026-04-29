# Discovery Services

Covers job discovery: querying SerpApi for job listings, detecting which ATS platform a URL belongs to, and parsing raw results into normalized lead data.

## AtsDetector

**Purpose:** Detects the ATS platform (Greenhouse, Lever, Ashby, etc.) from a job URL by matching the host.

**Inputs:** `url [String]` — the job listing URL to inspect.

**Success:** `{ success: true, response: { ats_type: String, url: String } }`

**Failure:** `{ success: false, response: { error: { message: String }, url: String } }`

**Raises:** `URI::InvalidURIError` when the URL cannot be parsed (internally rescued).

---

## QueryExecutor

**Purpose:** Executes SerpApi queries built from a SearchQuery record. **Stub — not yet implemented.**

**Inputs:** `search_query [SearchQuery]` — the query record with portal, title, and filters.

**Success:** `{ success: true, response: { results: Array } }` *(when implemented)*

**Failure:** `{ success: false, response: { error: { message: String } } }`

---

## ResultParser

**Purpose:** Parses raw SerpApi JSON results into structured lead attribute hashes. **Stub — not yet implemented.**

**Inputs:** `raw_results [Hash]` — raw JSON response from SerpApi.

**Success:** `{ success: true, response: { leads: Array<Hash> } }` *(when implemented)*

**Failure:** `{ success: false, response: { error: { message: String } } }`
