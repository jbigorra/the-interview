# Delta for Hybrid Matching

## ADDED Requirements

### Requirement: Stage 1 Keyword Filter
The system MUST perform a fast, deterministic keyword check against the job URL or fetched job description before using LLM resources.

#### Scenario: Keyword match failure
- GIVEN a discovered job
- WHEN the Stage 1 filter runs
- AND the job description does NOT contain at least one required keyword from the user's profile
- THEN the job MUST be moved to "Rejected" state
- AND the system MUST NOT trigger Stage 2 LLM evaluation

#### Scenario: Keyword match success
- GIVEN a discovered job
- WHEN the Stage 1 filter runs
- AND the job description contains required keywords
- THEN the job MUST remain in the pipeline
- AND the system MUST enqueue the job for Stage 2 LLM evaluation

### Requirement: Stage 2 LLM Evaluation
The system MUST use ruby_llm (Claude Haiku) to evaluate jobs that pass Stage 1 against the user's full profile and preferences.

#### Scenario: LLM evaluation success
- GIVEN a job that passed Stage 1
- WHEN the Stage 2 evaluation runs
- THEN the system MUST prompt Claude Haiku with the job description and user profile
- AND the LLM MUST return a structured JSON response with a match score (0-100) and rationale
- AND if the score is >= the user's threshold, the job MUST be moved to "New" state on the Kanban board
- AND if the score is < the user's threshold, the job MUST be moved to "Rejected" state

#### Scenario: LLM API failure
- GIVEN a job that passed Stage 1
- WHEN the Stage 2 evaluation runs
- AND the Claude API returns an error or timeout
- THEN the system MUST retry the evaluation up to 3 times with exponential backoff
- AND if all retries fail, the system MUST leave the job in a "Pending Evaluation" state and alert the user