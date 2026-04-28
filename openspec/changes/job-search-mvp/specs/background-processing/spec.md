# Delta for Background Processing

## ADDED Requirements

### Requirement: Solid Queue Jobs
The system MUST use Solid Queue (Rails 8 default) to manage asynchronous tasks: Discovery, Stage 1 Matching, and Stage 2 Matching.

#### Scenario: Enqueueing discovery
- GIVEN an active user profile
- WHEN the daily cron scheduler (e.g., solid_queue cron or whenever) triggers
- THEN a `JobDiscoveryJob` MUST be enqueued for that user

### Requirement: Rate Limiting and Throttling
The system MUST implement rate limiting for external API calls (SerpApi, Claude API) to avoid hitting tier limits.

#### Scenario: Claude API rate limit hit
- GIVEN a burst of 50 jobs passing Stage 1 simultaneously
- WHEN the `LlmEvaluationJob` instances are processed
- AND the Claude API returns an HTTP 429 Too Many Requests
- THEN Solid Queue MUST pause the failing job
- AND the job MUST be automatically retried using exponential backoff (e.g., base 60s)

### Requirement: Error Handling and Dead Letter Queue
The system MUST NOT silently drop jobs that fail repeatedly.

#### Scenario: Permanent job failure
- GIVEN a background job that has failed 5 times (max retries)
- WHEN the 5th attempt fails
- THEN Solid Queue MUST move the job to the failed/dead queue
- AND the system MUST NOT attempt to run it again automatically
- AND (Optional) the system MAY notify the admin via logs or error tracking (e.g., Sentry)