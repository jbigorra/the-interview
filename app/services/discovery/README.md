# Discovery Services

Covers job discovery: querying SerpApi for job listings, detecting which ATS platform a URL belongs to, parsing raw results into normalized lead data, and fetching full job details from ATS APIs.

## AtsDetector

**Status:** ✅ Implemented

**Purpose:** Detects the ATS platform (Greenhouse, Lever, Ashby, etc.) from a job URL by matching the host.

**Inputs:** `url [String]` — the job listing URL to inspect.

**Success:** `{ success: true, response: { ats_type: String, url: String } }`

**Failure:** `{ success: false, response: { error: { message: String }, url: String } }`

---

## QueryExecutor

**Status:** ✅ Implemented

**Purpose:** Executes SerpApi queries built from a SearchQuery record. Builds Google dork queries (`site:<portal> "<title>" "remote" <filters>`) and calls the SerpApi Google engine.

**Inputs:** `search_query [SearchQuery]` — the query record with portal, title, and filters.

**Success:** `{ success: true, response: { results: Array, query: String, count: Integer } }`

**Failure:** `{ success: false, response: { error: { message: String }, query: String } }`

---

## ResultParser

**Status:** ✅ Implemented

**Purpose:** Parses raw SerpApi JSON results into structured lead attribute hashes. Extracts title, company, location, URL, and description from organic search results.

**Inputs:** `raw_results [Array<Hash>]` — raw JSON response from SerpApi (symbolized keys).

**Success:** `{ success: true, response: { leads: Array<Hash>, count: Integer } }`

**Failure:** `{ success: false, response: { error: { message: String } } }`

---

## AtsFetcher

**Status:** ✅ Implemented

**Purpose:** Router service that dispatches to the correct ATS fetcher adapter (Greenhouse, Lever, Ashby) and normalizes the payload.

**Inputs:** `url: [String]`, `ats_type: [String]`

**Success:** `{ success: true, response: { title:, company:, location:, description:, raw_payload: } }`

**Failure:** `{ success: false, response: { error: { message: String } } }`

---

## GreenhouseFetcher / LeverFetcher / AshbyFetcher

**Status:** ✅ Implemented

**Purpose:** Fetch full job details from each ATS's public API. Each adapter calls the appropriate endpoint and normalizes the response into a common shape.
