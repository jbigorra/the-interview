# Matching Services

Covers the two-stage lead matching pipeline: Stage 1 keyword-based filtering and Stage 2 LLM-based scoring.

## KeywordEvaluator

**Purpose:** Stage 1 filter — evaluates whether a lead passes excluded/required keyword criteria.

**Inputs:** `lead: [Lead]`, `criterion: [MatchingCriterion, nil]`

**Success:** `{ success: true, response: { passed: Boolean, reason: String } }`
Always returns `success: true` — use `response[:passed]` to determine the outcome.

**Failure:** Never fails — criterion being nil is a valid input that auto-passes.

---

## LlmEvaluator

**Purpose:** Stage 2 scorer — evaluates a lead against the user's profile criteria using an LLM (Claude Haiku via ruby_llm). **Stub — not yet implemented.**

**Inputs:** `lead: [Lead]`, `criterion: [MatchingCriterion]`

**Success:** `{ success: true, response: { score: Integer, recommendation: String, reasoning: String } }` *(when implemented)*

**Failure:** `{ success: false, response: { error: { message: String } } }`
